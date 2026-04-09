import DevToolsKitMetrics
import Foundation
import Metrics
import SwiftData

/// Manages automatic rollup creation and data retention for the metrics store.
///
/// The engine runs periodic maintenance cycles that:
/// 1. Create hourly rollups from completed-hour raw observations
/// 2. Create daily rollups from completed-day hourly rollups
/// 3. Purge raw observations older than ``RetentionPolicy/rawDataTTL``
/// 4. Purge hourly rollups older than ``RetentionPolicy/hourlyRollupTTL``
/// 5. Purge daily rollups older than ``RetentionPolicy/dailyRollupTTL``
/// 6. Update metric definitions
///
/// All maintenance work runs on a background actor with a dedicated `ModelContext`,
/// keeping the main thread free for UI work.
///
/// > Since: 0.3.0
/// > Breaking change in 0.7.0: `runMaintenanceCycle()` is now `async`.
public final class RetentionEngine: Sendable {
    private let modelContainer: ModelContainer
    private let policy: RetentionPolicy
    private let lock = NSLock()
    private nonisolated(unsafe) var _maintenanceTask: Task<Void, Never>?
    private let worker: MaintenanceWorker

    /// Creates a retention engine with the given container and policy.
    public init(modelContainer: ModelContainer, policy: RetentionPolicy = .default) {
        self.modelContainer = modelContainer
        self.policy = policy
        self.worker = MaintenanceWorker(modelContainer: modelContainer, policy: policy)
    }

    deinit {
        _maintenanceTask?.cancel()
    }

    /// Start the periodic maintenance cycle.
    ///
    /// Launches a detached utility-priority task that runs maintenance at
    /// the interval specified by the retention policy.
    public func start() {
        lock.lock()
        defer { lock.unlock() }
        guard _maintenanceTask == nil else { return }
        let interval = policy.maintenanceInterval
        let worker = self.worker
        _maintenanceTask = Task.detached(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                await worker.runMaintenanceCycle()
                try? await Task.sleep(for: .seconds(interval))
                // Check if engine was deallocated
                if self == nil { break }
            }
        }
    }

    /// Stop the periodic maintenance cycle.
    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        _maintenanceTask?.cancel()
        _maintenanceTask = nil
    }

    /// Run a single maintenance cycle.
    ///
    /// > Since: 0.7.0 — now `async`. Previously synchronous and `@MainActor`-isolated.
    public func runMaintenanceCycle() async {
        await worker.runMaintenanceCycle()
    }

    /// Enforce the size ceiling defined in the retention policy.
    ///
    /// Prunes oldest raw observations until total on-disk size falls below
    /// `sizeCeilingBytes * sizeCeilingFloorRatio`. Returns `true` if pruning
    /// occurred, `false` if the ceiling is disabled or was not exceeded.
    @discardableResult
    public func enforceSizeCeiling() async throws -> Bool {
        try await worker.enforceSizeCeiling()
    }
}

// MARK: - MaintenanceWorker

/// Background actor that performs all retention maintenance work with a dedicated `ModelContext`.
private actor MaintenanceWorker {
    private let modelContainer: ModelContainer
    private let policy: RetentionPolicy

    init(modelContainer: ModelContainer, policy: RetentionPolicy) {
        self.modelContainer = modelContainer
        self.policy = policy
    }

    func runMaintenanceCycle() async {
        let context = ModelContext(modelContainer)
        let now = Date()
        let calendar = Calendar.current

        // 1. Create hourly rollups from raw observations in completed hours
        let hourlyBoundary =
            calendar.date(
                bySettingHour: calendar.component(.hour, from: now),
                minute: 0, second: 0, of: now) ?? now
        await createRollups(
            context: context,
            granularity: "hourly",
            interval: 3_600,
            boundary: hourlyBoundary
        )

        guard !Task.isCancelled else { return }
        await Task.yield()

        // 2. Create daily rollups from hourly rollups in completed days
        let dailyBoundary = calendar.startOfDay(for: now)
        await createDailyRollups(context: context, boundary: dailyBoundary)

        guard !Task.isCancelled else { return }
        await Task.yield()

        // 3. Purge raw observations
        let rawCutoff = now.addingTimeInterval(-policy.rawDataTTL)
        try? context.delete(
            model: MetricObservation.self,
            where: #Predicate { $0.timestamp < rawCutoff }
        )

        // 4. Purge old hourly rollups
        let hourlyCutoff = now.addingTimeInterval(-policy.hourlyRollupTTL)
        let hourlyGran = "hourly"
        try? context.delete(
            model: MetricRollup.self,
            where: #Predicate { $0.granularity == hourlyGran && $0.bucketEnd < hourlyCutoff }
        )

        // 5. Purge old daily rollups
        let dailyCutoff = now.addingTimeInterval(-policy.dailyRollupTTL)
        let dailyGran = "daily"
        try? context.delete(
            model: MetricRollup.self,
            where: #Predicate { $0.granularity == dailyGran && $0.bucketEnd < dailyCutoff }
        )

        guard !Task.isCancelled else { return }
        await Task.yield()

        // 6. Update metric definitions
        updateDefinitions(context: context)

        try? context.save()

        guard !Task.isCancelled else { return }
        await Task.yield()

        // 7. Enforce size ceiling (hysteresis pruning)
        _ = try? await enforceSizeCeiling()
    }

    // MARK: - Size Cap

    @discardableResult
    func enforceSizeCeiling() async throws -> Bool {
        guard let ceiling = policy.sizeCeilingBytes else { return false }

        guard let config = modelContainer.configurations.first,
              !config.isStoredInMemoryOnly
        else { return false }
        let dbURL = config.url

        // Pre-check: if already under ceiling, nothing to do.
        // We measure WAL-inclusive size: db + -wal + -shm.
        guard MetricsDatabaseFileStats.totalOnDiskBytes(dbURL: dbURL) > ceiling else {
            return false
        }

        // Phase 1 — prune oldest observations in 500-row batches.
        //
        // WAL-inclusive size grows during active deletes (each save() appends
        // WAL frames), so we do NOT re-stat mid-loop.  Instead we drain enough
        // rows to bring the logical data volume below the hysteresis floor,
        // trusting that the subsequent RESTART checkpoint will fold those frames
        // into the main file.  VACUUM (which physically shrinks the .db) is
        // deferred to the next app launch — see MetricsStack.create.
        //
        // The context is locally scoped so it deinits before checkpointRestart,
        // releasing its sqlite3 reader lock and minimising busy-wait time.
        try deleteToFloor()

        // Phase 2 — wal_checkpoint(RESTART).
        //
        // Folds all committed WAL frames back into the main file and resets the
        // WAL write position.  RESTART does not require zero active readers (unlike
        // TRUNCATE), so it succeeds while SwiftData's ModelContainer is open.
        // sqlite3_busy_timeout(5000) handles any transient lock contention.
        //
        // Errors surface to the caller; the maintenance cycle swallows them with
        // try? so a single bad checkpoint does not abort the cycle.
        try MetricsDatabaseFileStats.checkpointRestart(dbURL: dbURL)

        Counter(label: "devtoolskit.metrics.sizecap.triggered").increment()
        return true
    }

    /// Deletes the oldest `MetricObservation` rows in 500-row batches until
    /// the table is empty.
    ///
    /// We do not re-stat during deletion because WAL-inclusive size grows while
    /// deletes are being journalled.  The hysteresis floor (`target`) is enforced
    /// at the file level only after the subsequent `checkpointRestart` + at-launch
    /// VACUUM have reclaimed space.
    ///
    /// A locally scoped `ModelContext` deinits on return, releasing its sqlite3
    /// reader lock before `checkpointRestart` opens its handle.
    private func deleteToFloor() throws {
        let context = ModelContext(modelContainer)
        while true {
            var descriptor = FetchDescriptor<MetricObservation>(
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
            descriptor.fetchLimit = 500
            let batch = (try? context.fetch(descriptor)) ?? []
            guard !batch.isEmpty else { break }
            for obs in batch {
                context.delete(obs)
            }
            try? context.save()
        }
        try? context.save()
    }

    // MARK: - Hourly Rollups

    private func createRollups(
        context: ModelContext,
        granularity: String,
        interval: TimeInterval,
        boundary: Date
    ) async {
        // Filter at the database level — only fetch observations before the boundary
        let bnd = boundary
        var descriptor = FetchDescriptor<MetricObservation>(
            predicate: #Predicate { $0.timestamp < bnd }
        )
        descriptor.sortBy = [SortDescriptor(\.timestamp)]

        let observations = (try? context.fetch(descriptor)) ?? []
        guard !observations.isEmpty else { return }

        // Group by (label, typeRawValue, dimensionsKey, bucket)
        let gran = granularity

        var groups: [String: [MetricObservation]] = [:]
        for obs in observations {
            let bucketStart = Date(
                timeIntervalSinceReferenceDate: (obs.timestamp.timeIntervalSinceReferenceDate / interval).rounded(.down)
                    * interval
            )
            let bucketEnd = bucketStart.addingTimeInterval(interval)
            // Only rollup completed buckets
            guard bucketEnd <= boundary else { continue }

            let key =
                "\(obs.label)|\(obs.typeRawValue)|\(obs.dimensionsKey)|\(bucketStart.timeIntervalSinceReferenceDate)"
            groups[key, default: []].append(obs)
        }

        // Batch-fetch existing rollups to eliminate N+1 queries
        let existingRollupKeys = fetchExistingRollupKeys(context: context, granularity: gran)

        var iterationCount = 0
        for (key, obs) in groups {
            iterationCount += 1
            if iterationCount % 50 == 0 {
                guard !Task.isCancelled else { return }
                await Task.yield()
            }

            let components = key.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false)
            guard components.count == 4 else { continue }

            let label = String(components[0])
            let typeRaw = String(components[1])
            let dimsKey = String(components[2])
            let bucketRef = TimeInterval(components[3]) ?? 0
            let bucketStart = Date(timeIntervalSinceReferenceDate: bucketRef)
            let bucketEnd = bucketStart.addingTimeInterval(interval)

            // Check if rollup already exists using pre-fetched set
            let rollupKey = "\(label)|\(gran)|\(dimsKey)|\(bucketStart.timeIntervalSinceReferenceDate)"
            if existingRollupKeys.contains(rollupKey) {
                continue
            }

            let values = obs.map(\.value)
            let sum = values.reduce(0, +)
            let count = values.count
            let minVal = values.min() ?? 0
            let maxVal = values.max() ?? 0
            let avg = sum / Double(count)

            let rollup = MetricRollup(
                label: label,
                typeRawValue: typeRaw,
                dimensionsKey: dimsKey,
                granularity: granularity,
                bucketStart: bucketStart,
                bucketEnd: bucketEnd,
                count: count,
                sum: sum,
                min: minVal,
                max: maxVal,
                avg: avg
            )
            context.insert(rollup)
        }
    }

    // MARK: - Daily Rollups

    private func createDailyRollups(context: ModelContext, boundary: Date) async {
        let gran = "hourly"
        let bnd = boundary
        var descriptor = FetchDescriptor<MetricRollup>(
            predicate: #Predicate { $0.granularity == gran && $0.bucketEnd <= bnd }
        )
        descriptor.sortBy = [SortDescriptor(\.bucketStart)]

        guard let hourlyRollups = try? context.fetch(descriptor), !hourlyRollups.isEmpty else { return }

        let calendar = Calendar.current
        var groups: [String: [MetricRollup]] = [:]
        for rollup in hourlyRollups {
            let dayStart = calendar.startOfDay(for: rollup.bucketStart)
            guard dayStart.addingTimeInterval(86_400) <= boundary else { continue }
            let key =
                "\(rollup.label)|\(rollup.typeRawValue)|\(rollup.dimensionsKey)|\(dayStart.timeIntervalSinceReferenceDate)"
            groups[key, default: []].append(rollup)
        }

        // Batch-fetch existing daily rollups to eliminate N+1 queries
        let dailyGran = "daily"
        let existingRollupKeys = fetchExistingRollupKeys(context: context, granularity: dailyGran)

        var iterationCount = 0
        for (key, rollups) in groups {
            iterationCount += 1
            if iterationCount % 50 == 0 {
                guard !Task.isCancelled else { return }
                await Task.yield()
            }

            let components = key.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false)
            guard components.count == 4 else { continue }

            let label = String(components[0])
            let typeRaw = String(components[1])
            let dimsKey = String(components[2])
            let dayRef = TimeInterval(components[3]) ?? 0
            let dayStart = Date(timeIntervalSinceReferenceDate: dayRef)
            let dayEnd = dayStart.addingTimeInterval(86_400)

            // Check if rollup already exists using pre-fetched set
            let rollupKey = "\(label)|\(dailyGran)|\(dimsKey)|\(dayStart.timeIntervalSinceReferenceDate)"
            if existingRollupKeys.contains(rollupKey) {
                continue
            }

            let totalCount = rollups.reduce(0) { $0 + $1.count }
            let totalSum = rollups.reduce(0.0) { $0 + $1.sum }
            let minVal = rollups.map(\.min).min() ?? 0
            let maxVal = rollups.map(\.max).max() ?? 0
            let weightedAvg = totalCount > 0 ? totalSum / Double(totalCount) : 0

            let daily = MetricRollup(
                label: label,
                typeRawValue: typeRaw,
                dimensionsKey: dimsKey,
                granularity: "daily",
                bucketStart: dayStart,
                bucketEnd: dayEnd,
                count: totalCount,
                sum: totalSum,
                min: minVal,
                max: maxVal,
                avg: weightedAvg
            )
            context.insert(daily)
        }
    }

    // MARK: - Batch Rollup Lookup

    /// Fetch all existing rollup keys for a given granularity as a set for O(1) lookup.
    /// Eliminates N+1 per-group fetch queries.
    private func fetchExistingRollupKeys(context: ModelContext, granularity: String) -> Set<String> {
        let gran = granularity
        let descriptor = FetchDescriptor<MetricRollup>(
            predicate: #Predicate { $0.granularity == gran }
        )
        guard let rollups = try? context.fetch(descriptor) else { return [] }
        var keys = Set<String>()
        for rollup in rollups {
            let key = "\(rollup.label)|\(rollup.granularity)|\(rollup.dimensionsKey)|\(rollup.bucketStart.timeIntervalSinceReferenceDate)"
            keys.insert(key)
        }
        return keys
    }

    // MARK: - Definition Updates

    private func updateDefinitions(context: ModelContext) {
        let descriptor = FetchDescriptor<MetricDefinition>()
        guard let definitions = try? context.fetch(descriptor) else { return }

        for def in definitions {
            let label = def.label
            let typeRaw = def.typeRawValue
            var countDescriptor = FetchDescriptor<MetricObservation>(
                predicate: #Predicate { $0.label == label && $0.typeRawValue == typeRaw }
            )

            let count = (try? context.fetchCount(countDescriptor)) ?? 0
            def.totalObservations = count

            countDescriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
            countDescriptor.fetchLimit = 1
            if let latest = try? context.fetch(countDescriptor).first {
                def.lastSeenAt = latest.timestamp
            }
        }
    }
}
