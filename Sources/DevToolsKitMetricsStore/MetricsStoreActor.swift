import DevToolsKitMetrics
import Foundation
import Logging
import Metrics
import SwiftData

// MARK: - MetricObservationDTO

/// A `Sendable` value type that mirrors a persisted ``MetricObservation``.
///
/// Used at the ``MetricsStoreActor`` boundary so that `@Model` instances
/// never escape the actor. Callers produce a DTO from a ``MetricEntry``
/// and pass it across the isolation boundary for insertion.
///
/// > Since: 0.11.0
public struct MetricObservationDTO: Sendable {
    /// Unique identifier matching the ``MetricObservation/observationID``.
    public var id: UUID
    /// Timestamp of the observation.
    public var timestamp: Date
    /// Metric label.
    public var label: String
    /// Raw ``MetricType`` value.
    public var typeRawValue: String
    /// Recorded numeric value.
    public var value: Double
    /// Pre-computed sorted dimension key (e.g. "env=prod,region=us").
    public var dimensionsKey: String
    /// Key-value dimension pairs for this observation.
    public var dimensions: [(String, String)]

    /// Creates a DTO from a ``MetricEntry``.
    public init(entry: MetricEntry) {
        let dims = entry.dimensions.sorted { $0.0 < $1.0 }
        self.id = entry.id
        self.timestamp = entry.timestamp
        self.label = entry.label
        self.typeRawValue = entry.type.rawValue
        self.value = entry.value
        self.dimensionsKey = dims.map { "\($0.0)=\($0.1)" }.joined(separator: ",")
        self.dimensions = dims
    }
}

// MARK: - MetricsStoreActor

/// Single `ModelContext` owner for the metrics SwiftData container.
///
/// Every read and write to `tenrec-metrics.store` must go through this actor.
/// By owning the sole production `ModelContext`, the actor serializes all
/// fetch and delete operations, eliminating the data-race that caused
/// SwiftData `_PersistedProperty` assertion failures when
/// ``QueryExecutor/executeFromRaw`` fetched `MetricObservation` instances on
/// one background context while ``RetentionEngine/MaintenanceWorker`` deleted
/// rows on a separate context against the same `ModelContainer`.
///
/// Only `Sendable` value types cross the actor boundary:
/// - **in**: ``MetricObservationDTO``, ``DatabaseQuery``, `Date`, scalars
/// - **out**: ``QueryResult``, `Int`, `Bool`, `Int64`
///
/// > Since: 0.11.0
@ModelActor
public actor MetricsStoreActor {

    // MARK: - Private state

    nonisolated private static let logger = Logger(
        label: "devtoolskit.metricsstore.actor"
    )

    // MARK: - Configuration

    /// The on-disk URL of the SwiftData store, or `nil` for in-memory stores.
    ///
    /// Used by ``RetentionEngine`` and ``MetricsDatabase`` so they do not need
    /// to hold their own reference to the ``ModelContainer``.
    public var dbURL: URL? {
        modelContainer.configurations.first.flatMap {
            $0.isStoredInMemoryOnly ? nil : $0.url
        }
    }

    // MARK: - Query

    /// Execute a ``DatabaseQuery`` and return the result.
    ///
    /// The fetch and all in-memory `toMetricEntry()` mapping runs inside the
    /// actor so no `@Model` instance escapes the isolation boundary.
    public func execute(
        _ query: DatabaseQuery,
        unflushedEntries: [MetricEntry] = []
    ) throws -> QueryResult {
        try ActorQueryExecutor.execute(
            query, context: modelContext, unflushedEntries: unflushedEntries
        )
    }

    // MARK: - Write

    /// Persist a batch of ``MetricObservationDTO`` values.
    ///
    /// Each DTO is converted to a ``MetricObservation`` + ``MetricDimension``
    /// graph and upserted alongside the ``MetricDefinition`` registry.
    public func insert(_ dtos: [MetricObservationDTO]) throws {
        for dto in dtos {
            let dims = dto.dimensions.map { MetricDimension(key: $0.0, value: $0.1) }
            let obs = MetricObservation(
                observationID: dto.id,
                timestamp: dto.timestamp,
                label: dto.label,
                typeRawValue: dto.typeRawValue,
                value: dto.value,
                dimensionsKey: dto.dimensionsKey,
                dimensions: dims
            )
            modelContext.insert(obs)
            upsertDefinition(label: dto.label, typeRawValue: dto.typeRawValue, dto: dto)
        }
        try modelContext.save()
    }

    // MARK: - Retention

    /// Run a single maintenance cycle (rollups, TTL purge, size cap).
    ///
    /// All SwiftData work runs on the actor's `ModelContext`, which
    /// serializes it against concurrent reads via ``execute(_:unflushedEntries:)``.
    public func runMaintenanceCycle(policy: RetentionPolicy, dbURL: URL?) async throws {
        try await maintenanceRunCycle(policy: policy, dbURL: dbURL)
    }

    /// Enforce the size ceiling defined in the policy.
    ///
    /// Returns `true` if pruning occurred.
    @discardableResult
    public func enforceSizeCeiling(
        policy: RetentionPolicy,
        dbURL: URL?
    ) async throws -> Bool {
        try await maintenanceEnforceSizeCeiling(policy: policy, dbURL: dbURL)
    }

    // MARK: - Utilities

    /// Delete up to `batchSize` oldest ``MetricObservation`` rows.
    ///
    /// Used by ``MetricsDatabase/deleteOldestRawObservations(batchSize:)``.
    @discardableResult
    public func deleteOldestRawObservations(batchSize: Int) throws -> Int {
        var descriptor = FetchDescriptor<MetricObservation>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        descriptor.fetchLimit = batchSize
        let observations = try modelContext.fetch(descriptor)
        guard !observations.isEmpty else { return 0 }
        for obs in observations {
            modelContext.delete(obs)
        }
        try modelContext.save()
        return observations.count
    }

    /// Fetch all ``MetricDefinition`` rows, optionally filtered by label prefix.
    public func discover(prefix: String? = nil) throws -> [MetricDefinitionDTO] {
        let descriptor = FetchDescriptor<MetricDefinition>(
            sortBy: [SortDescriptor(\.label)]
        )
        let defs = try modelContext.fetch(descriptor)
        let filtered = prefix.map { p in defs.filter { $0.label.hasPrefix(p) } } ?? defs
        return filtered.map { MetricDefinitionDTO(definition: $0) }
    }

    /// Total on-disk size in bytes (db + wal + shm).
    public func totalOnDiskBytes(dbURL: URL?) throws -> Int64 {
        guard let dbURL else { return 0 }
        return MetricsDatabaseFileStats.totalOnDiskBytes(dbURL: dbURL)
    }

    /// Run `wal_checkpoint(RESTART)` on the store file.
    public func checkpointAndVacuum(dbURL: URL?) throws {
        guard let dbURL else { return }
        try modelContext.save()
        try MetricsDatabaseFileStats.checkpointRestart(dbURL: dbURL)
    }

    /// Delete all metrics data from the store.
    public func clear() throws {
        try modelContext.delete(model: MetricObservation.self)
        try modelContext.delete(model: MetricDimension.self)
        try modelContext.delete(model: MetricRollup.self)
        try modelContext.delete(model: MetricDefinition.self)
        try modelContext.save()
    }

    /// Delete all ``MetricObservation`` rows older than `date`.
    public func purge(olderThan date: Date) throws {
        let cutoff = date
        try modelContext.delete(
            model: MetricObservation.self,
            where: #Predicate { $0.timestamp < cutoff }
        )
        try modelContext.save()
    }

    /// Count of persisted ``MetricObservation`` rows.
    public func observationCount() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<MetricObservation>())
    }

    // MARK: - Test helpers

    /// Test-only: Fetch all raw observations with dimensions.
    ///
    /// Used to verify the crash fix: concurrent dimension access during deletion.
    /// Returns observations as (label, dimensions) tuples that match the code path
    /// that originally failed in #1429 when accessed concurrently with retention deletes.
    #if DEBUG
    public func testFetchRawObservationsWithDimensions() throws -> [(String, [(String, String)])] {
        let observations = try modelContext.fetch(FetchDescriptor<MetricObservation>())
        return observations.map { obs in
            (obs.label, obs.dimensions.map { ($0.key, $0.value) })
        }
    }
    #endif

    // MARK: - Private helpers

    private func upsertDefinition(
        label: String,
        typeRawValue: String,
        dto: MetricObservationDTO
    ) {
        let lbl = label
        let typeRaw = typeRawValue
        var defDescriptor = FetchDescriptor<MetricDefinition>(
            predicate: #Predicate { $0.label == lbl && $0.typeRawValue == typeRaw }
        )
        defDescriptor.fetchLimit = 1

        if let existing = try? modelContext.fetch(defDescriptor).first {
            existing.lastSeenAt = dto.timestamp
            existing.totalObservations += 1
            let dimKeys = Set(dto.dimensions.map(\.0))
            let existingKeys = Set(
                (try? JSONDecoder().decode([String].self, from: Data(existing.knownDimensionKeysJSON.utf8)))
                    ?? []
            )
            let allKeys = existingKeys.union(dimKeys)
            if let json = try? JSONEncoder().encode(Array(allKeys).sorted()),
               let str = String(data: json, encoding: .utf8)
            {
                existing.knownDimensionKeysJSON = str
            }
        } else {
            let dimKeys = dto.dimensions.map(\.0)
            let json =
                (try? JSONEncoder().encode(dimKeys))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            let def = MetricDefinition(
                label: label,
                typeRawValue: typeRawValue,
                knownDimensionKeysJSON: json,
                firstSeenAt: dto.timestamp,
                lastSeenAt: dto.timestamp,
                totalObservations: 1
            )
            modelContext.insert(def)
        }
    }

    // MARK: - Private maintenance helpers (formerly ActorMaintenanceWorker)
    //
    // All methods are actor-isolated and use `modelContext` directly.
    // No ModelContext is passed as a parameter, so Swift 6 strict concurrency
    // never flags these as cross-isolation sends.

    private func maintenanceRunCycle(policy: RetentionPolicy, dbURL: URL?) async throws {
        let now = Date()
        let calendar = Calendar.current

        let hourlyBoundary =
            calendar.date(
                bySettingHour: calendar.component(.hour, from: now),
                minute: 0, second: 0, of: now) ?? now
        maintenanceCreateRollups(granularity: "hourly", interval: 3_600, boundary: hourlyBoundary)

        let dailyBoundary = calendar.startOfDay(for: now)
        maintenanceCreateDailyRollups(boundary: dailyBoundary)

        let rawCutoff = now.addingTimeInterval(-policy.rawDataTTL)
        await maintenancePurgeTTLObservations(cutoff: rawCutoff, policy: policy)

        let hourlyCutoff = now.addingTimeInterval(-policy.hourlyRollupTTL)
        let hourlyGran = "hourly"
        try? modelContext.delete(
            model: MetricRollup.self,
            where: #Predicate { $0.granularity == hourlyGran && $0.bucketEnd < hourlyCutoff }
        )

        let dailyCutoff = now.addingTimeInterval(-policy.dailyRollupTTL)
        let dailyGran = "daily"
        try? modelContext.delete(
            model: MetricRollup.self,
            where: #Predicate { $0.granularity == dailyGran && $0.bucketEnd < dailyCutoff }
        )

        maintenanceUpdateDefinitions()
        try? modelContext.save()

        _ = try? await maintenanceEnforceSizeCeiling(policy: policy, dbURL: dbURL)
    }

    @discardableResult
    private func maintenanceEnforceSizeCeiling(policy: RetentionPolicy, dbURL: URL?) async throws -> Bool {
        guard let ceiling = policy.sizeCeilingBytes else { return false }
        guard let dbURL else { return false }
        guard MetricsDatabaseFileStats.totalOnDiskBytes(dbURL: dbURL) > ceiling else { return false }

        try await maintenanceDeleteToFloor(policy: policy)
        try MetricsDatabaseFileStats.checkpointRestart(dbURL: dbURL)
        Counter(label: "devtoolskit.metrics.sizecap.triggered").increment()
        return true
    }

    private func maintenanceDeleteToFloor(policy: RetentionPolicy) async throws {
        let archiver = policy.archiver
        while true {
            var descriptor = FetchDescriptor<MetricObservation>(
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
            descriptor.fetchLimit = 500
            let batch = (try? modelContext.fetch(descriptor)) ?? []
            guard !batch.isEmpty else { break }

            if let archiver {
                let snapshots = batch.map { obs in
                    ArchivedObservation(
                        timestamp: obs.timestamp,
                        label: obs.label,
                        typeRawValue: obs.typeRawValue,
                        value: obs.value,
                        dimensions: obs.dimensions.map { ($0.key, $0.value) }
                    )
                }
                do {
                    try await archiver.archive(observations: snapshots, reason: .sizeCap)
                } catch {
                    Self.logger.warning(
                        "RetentionArchiver failed during size-cap purge — deletion will proceed",
                        metadata: ["error": "\(error)"]
                    )
                }
            }

            for obs in batch { modelContext.delete(obs) }
            try? modelContext.save()
        }
        try? modelContext.save()
    }

    private func maintenancePurgeTTLObservations(cutoff: Date, policy: RetentionPolicy) async {
        if policy.archiver == nil {
            try? modelContext.delete(
                model: MetricObservation.self,
                where: #Predicate { $0.timestamp < cutoff }
            )
            return
        }

        let archiver = policy.archiver
        let cutoffDate = cutoff
        while true {
            var descriptor = FetchDescriptor<MetricObservation>(
                predicate: #Predicate { $0.timestamp < cutoffDate },
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
            descriptor.fetchLimit = 8_000
            let batch = (try? modelContext.fetch(descriptor)) ?? []
            guard !batch.isEmpty else { break }

            let snapshots = batch.map { obs in
                ArchivedObservation(
                    timestamp: obs.timestamp,
                    label: obs.label,
                    typeRawValue: obs.typeRawValue,
                    value: obs.value,
                    dimensions: obs.dimensions.map { ($0.key, $0.value) }
                )
            }
            do {
                try await archiver?.archive(observations: snapshots, reason: .ttl)
            } catch {
                Self.logger.warning(
                    "RetentionArchiver failed during TTL purge — deletion will proceed",
                    metadata: ["error": "\(error)"]
                )
            }

            for obs in batch { modelContext.delete(obs) }
            try? modelContext.save()
        }
    }

    private func maintenanceCreateRollups(granularity: String, interval: TimeInterval, boundary: Date) {
        let bnd = boundary
        var descriptor = FetchDescriptor<MetricObservation>(
            predicate: #Predicate { $0.timestamp < bnd }
        )
        descriptor.sortBy = [SortDescriptor(\.timestamp)]

        let observations = (try? modelContext.fetch(descriptor)) ?? []
        guard !observations.isEmpty else { return }

        let gran = granularity
        var groups: [String: [MetricObservation]] = [:]
        for obs in observations {
            let bucketStart = Date(
                timeIntervalSinceReferenceDate:
                    (obs.timestamp.timeIntervalSinceReferenceDate / interval).rounded(.down) * interval
            )
            let bucketEnd = bucketStart.addingTimeInterval(interval)
            guard bucketEnd <= boundary else { continue }
            let key = "\(obs.label)|\(obs.typeRawValue)|\(obs.dimensionsKey)|\(bucketStart.timeIntervalSinceReferenceDate)"
            groups[key, default: []].append(obs)
        }

        let existingKeys = maintenanceFetchExistingRollupKeys(granularity: gran)
        for (key, obs) in groups {
            let components = key.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false)
            guard components.count == 4 else { continue }
            let label = String(components[0])
            let typeRaw = String(components[1])
            let dimsKey = String(components[2])
            let bucketRef = TimeInterval(components[3]) ?? 0
            let bucketStart = Date(timeIntervalSinceReferenceDate: bucketRef)
            let bucketEnd = bucketStart.addingTimeInterval(interval)
            let rollupKey = "\(label)|\(gran)|\(dimsKey)|\(bucketStart.timeIntervalSinceReferenceDate)"
            if existingKeys.contains(rollupKey) { continue }
            let values = obs.map(\.value)
            let sum = values.reduce(0, +)
            let count = values.count
            let minVal = values.min() ?? 0
            let maxVal = values.max() ?? 0
            let avg = sum / Double(count)
            let rollup = MetricRollup(
                label: label, typeRawValue: typeRaw, dimensionsKey: dimsKey,
                granularity: granularity, bucketStart: bucketStart, bucketEnd: bucketEnd,
                count: count, sum: sum, min: minVal, max: maxVal, avg: avg
            )
            modelContext.insert(rollup)
        }
    }

    private func maintenanceCreateDailyRollups(boundary: Date) {
        let gran = "hourly"
        let bnd = boundary
        var descriptor = FetchDescriptor<MetricRollup>(
            predicate: #Predicate { $0.granularity == gran && $0.bucketEnd <= bnd }
        )
        descriptor.sortBy = [SortDescriptor(\.bucketStart)]
        guard let hourlyRollups = try? modelContext.fetch(descriptor), !hourlyRollups.isEmpty else { return }

        let calendar = Calendar.current
        var groups: [String: [MetricRollup]] = [:]
        for rollup in hourlyRollups {
            let dayStart = calendar.startOfDay(for: rollup.bucketStart)
            guard dayStart.addingTimeInterval(86_400) <= boundary else { continue }
            let key = "\(rollup.label)|\(rollup.typeRawValue)|\(rollup.dimensionsKey)|\(dayStart.timeIntervalSinceReferenceDate)"
            groups[key, default: []].append(rollup)
        }

        let dailyGran = "daily"
        let existingKeys = maintenanceFetchExistingRollupKeys(granularity: dailyGran)
        for (key, rollups) in groups {
            let components = key.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false)
            guard components.count == 4 else { continue }
            let label = String(components[0])
            let typeRaw = String(components[1])
            let dimsKey = String(components[2])
            let dayRef = TimeInterval(components[3]) ?? 0
            let dayStart = Date(timeIntervalSinceReferenceDate: dayRef)
            let dayEnd = dayStart.addingTimeInterval(86_400)
            let rollupKey = "\(label)|\(dailyGran)|\(dimsKey)|\(dayStart.timeIntervalSinceReferenceDate)"
            if existingKeys.contains(rollupKey) { continue }
            let totalCount = rollups.reduce(0) { $0 + $1.count }
            let totalSum = rollups.reduce(0.0) { $0 + $1.sum }
            let minVal = rollups.map(\.min).min() ?? 0
            let maxVal = rollups.map(\.max).max() ?? 0
            let weightedAvg = totalCount > 0 ? totalSum / Double(totalCount) : 0
            let daily = MetricRollup(
                label: label, typeRawValue: typeRaw, dimensionsKey: dimsKey,
                granularity: "daily", bucketStart: dayStart, bucketEnd: dayEnd,
                count: totalCount, sum: totalSum, min: minVal, max: maxVal, avg: weightedAvg
            )
            modelContext.insert(daily)
        }
    }

    private func maintenanceFetchExistingRollupKeys(granularity: String) -> Set<String> {
        let gran = granularity
        let descriptor = FetchDescriptor<MetricRollup>(predicate: #Predicate { $0.granularity == gran })
        guard let rollups = try? modelContext.fetch(descriptor) else { return [] }
        var keys = Set<String>()
        for rollup in rollups {
            keys.insert("\(rollup.label)|\(rollup.granularity)|\(rollup.dimensionsKey)|\(rollup.bucketStart.timeIntervalSinceReferenceDate)")
        }
        return keys
    }

    private func maintenanceUpdateDefinitions() {
        let descriptor = FetchDescriptor<MetricDefinition>()
        guard let definitions = try? modelContext.fetch(descriptor) else { return }
        for def in definitions {
            let label = def.label
            let typeRaw = def.typeRawValue
            var countDescriptor = FetchDescriptor<MetricObservation>(
                predicate: #Predicate { $0.label == label && $0.typeRawValue == typeRaw }
            )
            let count = (try? modelContext.fetchCount(countDescriptor)) ?? 0
            def.totalObservations = count
            countDescriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
            countDescriptor.fetchLimit = 1
            if let latest = try? modelContext.fetch(countDescriptor).first {
                def.lastSeenAt = latest.timestamp
            }
        }
    }
}

// MARK: - MetricDefinitionDTO

/// A `Sendable` value type mirroring a ``MetricDefinition`` row.
///
/// > Since: 0.11.0
public struct MetricDefinitionDTO: Sendable {
    public let label: String
    public let typeRawValue: String
    public let knownDimensionKeysJSON: String
    public let firstSeenAt: Date
    public let lastSeenAt: Date
    public let totalObservations: Int

    init(definition: MetricDefinition) {
        self.label = definition.label
        self.typeRawValue = definition.typeRawValue
        self.knownDimensionKeysJSON = definition.knownDimensionKeysJSON
        self.firstSeenAt = definition.firstSeenAt
        self.lastSeenAt = definition.lastSeenAt
        self.totalObservations = definition.totalObservations
    }
}

// MARK: - ActorQueryExecutor

/// Synchronous query helper that runs inside ``MetricsStoreActor``'s context.
///
/// Mirrors the logic of ``QueryExecutor`` but receives a pre-existing
/// `ModelContext` rather than constructing a new one, ensuring all fetches
/// run on the actor's single context.
enum ActorQueryExecutor {
    static func execute(
        _ query: DatabaseQuery,
        context: ModelContext,
        unflushedEntries: [MetricEntry]
    ) throws -> QueryResult {
        if query.preferRollups,
           let timeBucket = query.timeBucket,
           let agg = query.aggregation,
           query.groupByDimension == nil,
           let labelFilter = query.labelFilter,
           case .exact(let label) = labelFilter,
           let granularity = rollupGranularity(for: timeBucket)
        {
            let result = try executeFromRollups(
                query, label: label, granularity: granularity,
                aggregation: agg, timeBucket: timeBucket, context: context
            )
            if !result.rows.isEmpty { return result }
        }
        return try executeFromRaw(query, context: context, unflushedEntries: unflushedEntries)
    }

    private static func executeFromRaw(
        _ query: DatabaseQuery,
        context: ModelContext,
        unflushedEntries: [MetricEntry]
    ) throws -> QueryResult {
        var descriptor = FetchDescriptor<MetricObservation>()
        var predicates: [Predicate<MetricObservation>] = []

        if let labelFilter = query.labelFilter {
            switch labelFilter {
            case .exact(let value):
                let label = value
                predicates.append(#Predicate { $0.label == label })
            case .prefix, .contains:
                break
            }
        }
        if let typeFilter = query.typeFilter {
            let raw = typeFilter.rawValue
            predicates.append(#Predicate { $0.typeRawValue == raw })
        }
        if let start = query.startDate {
            let startDate = start
            predicates.append(#Predicate { $0.timestamp >= startDate })
        }
        if let end = query.endDate {
            let endDate = end
            predicates.append(#Predicate { $0.timestamp <= endDate })
        }

        if !predicates.isEmpty {
            descriptor.predicate = combinePredicates(predicates)
        }
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]

        let observations = try context.fetch(descriptor)
        // toMetricEntry() reads @Model properties — safe here because we hold the actor lock.
        var entries = observations.map { $0.toMetricEntry() }

        let filtered = filterEntries(unflushedEntries, matching: query)
        entries.append(contentsOf: filtered)
        entries.sort { $0.timestamp < $1.timestamp }

        let totalScanned = entries.count

        if let labelFilter = query.labelFilter {
            entries = entries.filter { labelFilter.matches($0.label) }
        }
        if let dimFilters = query.dimensionFilters {
            entries = entries.filter { entry in
                dimFilters.allSatisfy { req in
                    entry.dimensions.contains { $0.0 == req.0 && $0.1 == req.1 }
                }
            }
        }

        let rows: [QueryResultRow]
        if let timeBucket = query.timeBucket {
            rows = bucketAndAggregate(
                entries, timeBucket: timeBucket,
                aggregation: query.aggregation ?? .avg,
                groupByDimension: query.groupByDimension,
                gapFill: query.gapFill,
                startDate: query.startDate,
                endDate: query.endDate
            )
        } else if let groupBy = query.groupByDimension {
            rows = groupByDimensionAndAggregate(
                entries, dimensionKey: groupBy,
                aggregation: query.aggregation ?? .avg
            )
        } else if let agg = query.aggregation {
            rows = aggregateByLabel(entries, aggregation: agg)
        } else {
            rows = entries.map { entry in
                QueryResultRow(
                    label: entry.label,
                    bucketStart: entry.timestamp,
                    value: entry.value,
                    count: 1
                )
            }
        }

        let sorted = sortRows(rows, by: query.sortBy)
        let limited = query.limit.map { Array(sorted.prefix($0)) } ?? sorted
        return QueryResult(rows: limited, observationsScanned: totalScanned)
    }

    private static func rollupGranularity(for bucket: TimeBucket) -> String? {
        switch bucket {
        case .hour: "hourly"
        case .day: "daily"
        default: nil
        }
    }

    private static func executeFromRollups(
        _ query: DatabaseQuery,
        label: String,
        granularity: String,
        aggregation: AggregationFunction,
        timeBucket: TimeBucket,
        context: ModelContext
    ) throws -> QueryResult {
        var descriptor = FetchDescriptor<MetricRollup>()
        var predicates: [Predicate<MetricRollup>] = []

        let lbl = label
        let gran = granularity
        predicates.append(#Predicate { $0.label == lbl && $0.granularity == gran })

        if let typeFilter = query.typeFilter {
            let raw = typeFilter.rawValue
            predicates.append(#Predicate { $0.typeRawValue == raw })
        }
        if let start = query.startDate {
            let startDate = start
            predicates.append(#Predicate { $0.bucketStart >= startDate })
        }
        if let end = query.endDate {
            let endDate = end
            predicates.append(#Predicate { $0.bucketEnd <= endDate })
        }

        if !predicates.isEmpty {
            descriptor.predicate = combineRollupPredicates(predicates)
        }
        descriptor.sortBy = [SortDescriptor(\.bucketStart, order: .forward)]

        let rollups = try context.fetch(descriptor)
        guard !rollups.isEmpty else { return QueryResult(rows: []) }

        var rows = rollups.map { rollup -> QueryResultRow in
            let value: Double = switch aggregation {
            case .sum: rollup.sum
            case .avg: rollup.avg
            case .min: rollup.min
            case .max: rollup.max
            case .count: Double(rollup.count)
            case .latest: rollup.avg
            case .p50, .p95, .p99: .nan
            }
            return QueryResultRow(
                label: rollup.label,
                bucketStart: rollup.bucketStart,
                value: value,
                count: rollup.count
            )
        }

        if query.gapFill != .none {
            rows = applyGapFill(
                rows, strategy: query.gapFill, timeBucket: timeBucket,
                startDate: query.startDate, endDate: query.endDate, label: label
            )
        }

        let sorted = sortRows(rows, by: query.sortBy)
        let limited = query.limit.map { Array(sorted.prefix($0)) } ?? sorted
        return QueryResult(rows: limited, observationsScanned: 0)
    }

    private static func bucketAndAggregate(
        _ entries: [MetricEntry],
        timeBucket: TimeBucket,
        aggregation: AggregationFunction,
        groupByDimension: String?,
        gapFill: GapFillStrategy,
        startDate: Date?,
        endDate: Date?
    ) -> [QueryResultRow] {
        if let dimKey = groupByDimension {
            var groups: [String: [Date: [(Double, Date)]]] = [:]
            for entry in entries {
                let bucket = timeBucket.bucketStart(for: entry.timestamp)
                let dimValue = entry.dimensions.first { $0.0 == dimKey }?.1 ?? "(none)"
                groups[dimValue, default: [:]][bucket, default: []].append((entry.value, entry.timestamp))
            }
            var rows: [QueryResultRow] = []
            for (dimValue, buckets) in groups {
                for (bucket, pairs) in buckets {
                    let values = pairs.map(\.0)
                    let timestamps = pairs.map(\.1)
                    if let agg = aggregation.compute(values, timestamps: timestamps) {
                        rows.append(QueryResultRow(
                            label: entries.first?.label ?? "",
                            dimensionValue: dimValue,
                            bucketStart: bucket,
                            value: agg,
                            count: values.count
                        ))
                    }
                }
            }
            return rows
        }

        var buckets: [String: [Date: [(Double, Date)]]] = [:]
        for entry in entries {
            let bucket = timeBucket.bucketStart(for: entry.timestamp)
            buckets[entry.label, default: [:]][bucket, default: []].append((entry.value, entry.timestamp))
        }
        var rows: [QueryResultRow] = []
        for (label, labelBuckets) in buckets {
            for (bucket, pairs) in labelBuckets {
                let values = pairs.map(\.0)
                let timestamps = pairs.map(\.1)
                if let agg = aggregation.compute(values, timestamps: timestamps) {
                    rows.append(QueryResultRow(label: label, bucketStart: bucket, value: agg, count: values.count))
                }
            }
            if gapFill != .none {
                let labelRows = rows.filter { $0.label == label }
                let filled = applyGapFill(
                    labelRows, strategy: gapFill, timeBucket: timeBucket,
                    startDate: startDate, endDate: endDate, label: label
                )
                rows = rows.filter { $0.label != label } + filled
            }
        }
        return rows
    }

    private static func groupByDimensionAndAggregate(
        _ entries: [MetricEntry],
        dimensionKey: String,
        aggregation: AggregationFunction
    ) -> [QueryResultRow] {
        var groups: [String: [(Double, Date)]] = [:]
        for entry in entries {
            let dimValue = entry.dimensions.first { $0.0 == dimensionKey }?.1 ?? "(none)"
            groups[dimValue, default: []].append((entry.value, entry.timestamp))
        }
        return groups.compactMap { dimValue, pairs in
            let values = pairs.map(\.0)
            let timestamps = pairs.map(\.1)
            guard let agg = aggregation.compute(values, timestamps: timestamps) else { return nil }
            return QueryResultRow(
                label: entries.first?.label ?? "",
                dimensionValue: dimValue,
                value: agg,
                count: values.count
            )
        }
    }

    private static func aggregateByLabel(
        _ entries: [MetricEntry],
        aggregation: AggregationFunction
    ) -> [QueryResultRow] {
        var groups: [String: [(Double, Date)]] = [:]
        for entry in entries {
            groups[entry.label, default: []].append((entry.value, entry.timestamp))
        }
        return groups.compactMap { label, pairs in
            let values = pairs.map(\.0)
            let timestamps = pairs.map(\.1)
            guard let agg = aggregation.compute(values, timestamps: timestamps) else { return nil }
            return QueryResultRow(label: label, value: agg, count: values.count)
        }
    }

    private static func applyGapFill(
        _ rows: [QueryResultRow],
        strategy: GapFillStrategy,
        timeBucket: TimeBucket,
        startDate: Date?,
        endDate: Date?,
        label: String
    ) -> [QueryResultRow] {
        guard strategy != .none else { return rows }
        let sortedRows = rows.sorted {
            ($0.bucketStart ?? .distantPast) < ($1.bucketStart ?? .distantPast)
        }
        guard let firstBucket =
            (startDate.map { timeBucket.bucketStart(for: $0) } ?? sortedRows.first?.bucketStart)
        else { return rows }
        let lastBucket =
            endDate.map { timeBucket.bucketStart(for: $0) }
            ?? sortedRows.last?.bucketStart ?? firstBucket

        var existing: [Date: QueryResultRow] = [:]
        for row in sortedRows { if let bs = row.bucketStart { existing[bs] = row } }

        var result: [QueryResultRow] = []
        var current = firstBucket
        var lastValue: Double = 0
        let interval = timeBucket.interval

        while current <= lastBucket {
            if let row = existing[current] {
                result.append(row)
                lastValue = row.value
            } else {
                let fillValue: Double = switch strategy {
                case .zero: 0
                case .carryForward: lastValue
                case .none: 0
                }
                result.append(QueryResultRow(label: label, bucketStart: current, value: fillValue, count: 0))
            }
            current = current.addingTimeInterval(interval)
        }
        return result
    }

    private static func sortRows(_ rows: [QueryResultRow], by sort: ResultSort) -> [QueryResultRow] {
        switch sort {
        case .valueAscending: rows.sorted { $0.value < $1.value }
        case .valueDescending: rows.sorted { $0.value > $1.value }
        case .labelAscending: rows.sorted { $0.label < $1.label }
        case .timeAscending: rows.sorted { ($0.bucketStart ?? .distantPast) < ($1.bucketStart ?? .distantPast) }
        case .timeDescending: rows.sorted { ($0.bucketStart ?? .distantFuture) > ($1.bucketStart ?? .distantFuture) }
        }
    }

    private static func filterEntries(
        _ entries: [MetricEntry],
        matching query: DatabaseQuery
    ) -> [MetricEntry] {
        var result = entries
        if let labelFilter = query.labelFilter { result = result.filter { labelFilter.matches($0.label) } }
        if let typeFilter = query.typeFilter { result = result.filter { $0.type == typeFilter } }
        if let start = query.startDate { result = result.filter { $0.timestamp >= start } }
        if let end = query.endDate { result = result.filter { $0.timestamp <= end } }
        if let dimFilters = query.dimensionFilters {
            result = result.filter { entry in
                dimFilters.allSatisfy { req in
                    entry.dimensions.contains { $0.0 == req.0 && $0.1 == req.1 }
                }
            }
        }
        return result
    }

    private static func combinePredicates(
        _ predicates: [Predicate<MetricObservation>]
    ) -> Predicate<MetricObservation> {
        guard var combined = predicates.first else {
            return #Predicate<MetricObservation> { _ in true }
        }
        for predicate in predicates.dropFirst() {
            let prev = combined
            let next = predicate
            combined = #Predicate { prev.evaluate($0) && next.evaluate($0) }
        }
        return combined
    }

    private static func combineRollupPredicates(
        _ predicates: [Predicate<MetricRollup>]
    ) -> Predicate<MetricRollup> {
        guard var combined = predicates.first else {
            return #Predicate<MetricRollup> { _ in true }
        }
        for predicate in predicates.dropFirst() {
            let prev = combined
            let next = predicate
            combined = #Predicate { prev.evaluate($0) && next.evaluate($0) }
        }
        return combined
    }
}
