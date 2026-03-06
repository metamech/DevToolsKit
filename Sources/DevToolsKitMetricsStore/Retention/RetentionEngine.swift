import Foundation
import SwiftData
import DevToolsKitMetrics

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
/// > Since: 0.3.0
@MainActor
public final class RetentionEngine: Sendable {
    private let modelContainer: ModelContainer
    private let policy: RetentionPolicy
    @ObservationIgnored private nonisolated(unsafe) var maintenanceTask: Task<Void, Never>?

    /// Creates a retention engine with the given container and policy.
    public init(modelContainer: ModelContainer, policy: RetentionPolicy = .default) {
        self.modelContainer = modelContainer
        self.policy = policy
    }

    deinit {
        maintenanceTask?.cancel()
    }

    /// Start the periodic maintenance cycle.
    public func start() {
        guard maintenanceTask == nil else { return }
        let interval = policy.maintenanceInterval
        maintenanceTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.runMaintenanceCycle()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    /// Stop the periodic maintenance cycle.
    public func stop() {
        maintenanceTask?.cancel()
        maintenanceTask = nil
    }

    /// Run a single maintenance cycle.
    public func runMaintenanceCycle() {
        let context = modelContainer.mainContext
        let now = Date()
        let calendar = Calendar.current

        // 1. Create hourly rollups from raw observations in completed hours
        let hourlyBoundary = calendar.date(bySettingHour: calendar.component(.hour, from: now),
                                           minute: 0, second: 0, of: now) ?? now
        createRollups(
            context: context,
            granularity: "hourly",
            interval: 3_600,
            boundary: hourlyBoundary
        )

        // 2. Create daily rollups from hourly rollups in completed days
        let dailyBoundary = calendar.startOfDay(for: now)
        createDailyRollups(context: context, boundary: dailyBoundary)

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

        // 6. Update metric definitions
        updateDefinitions(context: context)

        try? context.save()
    }

    // MARK: - Hourly Rollups

    private func createRollups(
        context: ModelContext,
        granularity: String,
        interval: TimeInterval,
        boundary: Date
    ) {
        var descriptor = FetchDescriptor<MetricObservation>()
        descriptor.sortBy = [SortDescriptor(\.timestamp)]

        let allObservations = (try? context.fetch(descriptor)) ?? []
        let observations = allObservations.filter { $0.timestamp < boundary }
        guard !observations.isEmpty else { return }

        // Group by (label, typeRawValue, dimensionsKey, bucket)
        let gran = granularity

        var groups: [String: [MetricObservation]] = [:]
        for obs in observations {
            let bucketStart = Date(
                timeIntervalSinceReferenceDate:
                    (obs.timestamp.timeIntervalSinceReferenceDate / interval).rounded(.down) * interval
            )
            let bucketEnd = bucketStart.addingTimeInterval(interval)
            // Only rollup completed buckets
            guard bucketEnd <= boundary else { continue }

            let key = "\(obs.label)|\(obs.typeRawValue)|\(obs.dimensionsKey)|\(bucketStart.timeIntervalSinceReferenceDate)"
            groups[key, default: []].append(obs)
        }

        for (key, obs) in groups {
            let components = key.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false)
            guard components.count == 4 else { continue }

            let label = String(components[0])
            let typeRaw = String(components[1])
            let dimsKey = String(components[2])
            let bucketRef = TimeInterval(components[3]) ?? 0
            let bucketStart = Date(timeIntervalSinceReferenceDate: bucketRef)
            let bucketEnd = bucketStart.addingTimeInterval(interval)

            // Check if rollup already exists
            let bStart = bucketStart
            let lbl = label
            var existingDescriptor = FetchDescriptor<MetricRollup>(
                predicate: #Predicate {
                    $0.label == lbl && $0.granularity == gran && $0.bucketStart == bStart
                        && $0.dimensionsKey == dimsKey
                }
            )
            existingDescriptor.fetchLimit = 1
            if let existing = try? context.fetch(existingDescriptor), !existing.isEmpty {
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

    private func createDailyRollups(context: ModelContext, boundary: Date) {
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
            let key = "\(rollup.label)|\(rollup.typeRawValue)|\(rollup.dimensionsKey)|\(dayStart.timeIntervalSinceReferenceDate)"
            groups[key, default: []].append(rollup)
        }

        let dailyGran = "daily"
        for (key, rollups) in groups {
            let components = key.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false)
            guard components.count == 4 else { continue }

            let label = String(components[0])
            let typeRaw = String(components[1])
            let dimsKey = String(components[2])
            let dayRef = TimeInterval(components[3]) ?? 0
            let dayStart = Date(timeIntervalSinceReferenceDate: dayRef)
            let dayEnd = dayStart.addingTimeInterval(86_400)

            let lbl = label
            let dStart = dayStart
            var existingDescriptor = FetchDescriptor<MetricRollup>(
                predicate: #Predicate {
                    $0.label == lbl && $0.granularity == dailyGran && $0.bucketStart == dStart
                        && $0.dimensionsKey == dimsKey
                }
            )
            existingDescriptor.fetchLimit = 1
            if let existing = try? context.fetch(existingDescriptor), !existing.isEmpty {
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
