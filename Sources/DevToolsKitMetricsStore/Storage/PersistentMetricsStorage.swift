import DevToolsKitMetrics
import Foundation
import SwiftData

/// Notification posted after each batch flush to the persistent store.
///
/// > Since: 0.3.0
extension Notification.Name {
    public static let metricsStoreDidFlush = Notification.Name("DevToolsKitMetricsStoreDidFlush")
}

/// SwiftData-backed persistent metrics storage.
///
/// Conforms to ``MetricsStorage`` for drop-in replacement of ``InMemoryMetricsStorage``.
/// Records are buffered and flushed in batches for performance. Flush work runs on a
/// background actor with a dedicated `ModelContext`, keeping the main thread free.
///
/// > Since: 0.3.0
/// > Breaking change in 0.7.0: `flushNow()` is now `async`.
@MainActor
@Observable
public final class PersistentMetricsStorage: MetricsStorage, Sendable {
    private let modelContainer: ModelContainer
    private let batchSize: Int
    private let flushInterval: TimeInterval
    private var buffer: [MetricEntry] = []
    @ObservationIgnored private nonisolated(unsafe) var flushTask: Task<Void, Never>?
    private var knownIdentifiers: Set<MetricIdentifier> = []
    private let flushWorker: FlushWorker

    /// Creates a persistent storage backed by the given model container.
    ///
    /// - Parameters:
    ///   - modelContainer: The SwiftData container to persist metrics into.
    ///   - batchSize: Number of entries to buffer before flushing. Defaults to 50.
    ///   - flushInterval: Maximum seconds between flushes. Defaults to 1.0.
    public init(
        modelContainer: ModelContainer,
        batchSize: Int = 50,
        flushInterval: TimeInterval = 1.0
    ) {
        self.modelContainer = modelContainer
        self.batchSize = batchSize
        self.flushInterval = flushInterval
        self.flushWorker = FlushWorker(modelContainer: modelContainer)
        scheduleFlush()
    }

    deinit {
        flushTask?.cancel()
    }

    // MARK: - MetricsStorage

    public func record(_ entry: MetricEntry) {
        buffer.append(entry)
        knownIdentifiers.insert(MetricIdentifier(entry: entry))

        if buffer.count >= batchSize {
            Task { await flushNow() }
        }
    }

    public func query(_ query: MetricsQuery) -> [MetricEntry] {
        let context = modelContainer.mainContext
        var descriptor = FetchDescriptor<MetricObservation>()
        var predicates: [Predicate<MetricObservation>] = []

        if let label = query.label {
            let lbl = label
            predicates.append(#Predicate { $0.label == lbl })
        }
        if let type = query.type {
            let raw = type.rawValue
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

        var entries: [MetricEntry]
        do {
            let observations = try context.fetch(descriptor)
            entries = observations.map { $0.toMetricEntry() }
        } catch {
            entries = []
        }

        // Merge unflushed buffer
        var buffered = buffer
        if let label = query.label {
            buffered = buffered.filter { $0.label == label }
        }
        if let type = query.type {
            buffered = buffered.filter { $0.type == type }
        }
        if let start = query.startDate {
            buffered = buffered.filter { $0.timestamp >= start }
        }
        if let end = query.endDate {
            buffered = buffered.filter { $0.timestamp <= end }
        }
        entries.append(contentsOf: buffered)

        // Dimension filtering (in-memory for both)
        if let dims = query.dimensions {
            entries = entries.filter { entry in
                dims.allSatisfy { req in
                    entry.dimensions.contains { $0.0 == req.0 && $0.1 == req.1 }
                }
            }
        }

        // Sort
        switch query.sort {
        case .timestampAscending:
            entries.sort { $0.timestamp < $1.timestamp }
        case .timestampDescending:
            entries.sort { $0.timestamp > $1.timestamp }
        case .valueAscending:
            entries.sort { $0.value < $1.value }
        case .valueDescending:
            entries.sort { $0.value > $1.value }
        }

        if let limit = query.limit {
            entries = Array(entries.prefix(limit))
        }

        return entries
    }

    public func summary(for identifier: MetricIdentifier) -> MetricSummary? {
        let matching = query(
            MetricsQuery(
                label: identifier.label,
                type: identifier.type
            )
        ).filter { MetricIdentifier(entry: $0) == identifier }

        return MetricsAggregation.summarize(matching, identifier: identifier)
    }

    public func knownMetrics() -> [MetricIdentifier] {
        // Merge persisted definitions with in-memory known identifiers
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<MetricDefinition>()
        let definitions = (try? context.fetch(descriptor)) ?? []

        var identifiers = knownIdentifiers
        for def in definitions {
            if let type = MetricType(rawValue: def.typeRawValue) {
                identifiers.insert(
                    MetricIdentifier(
                        label: def.label,
                        dimensions: [],
                        type: type
                    ))
            }
        }
        return Array(identifiers)
    }

    public func clear() {
        buffer.removeAll()
        knownIdentifiers.removeAll()

        let context = modelContainer.mainContext
        do {
            try context.delete(model: MetricObservation.self)
            try context.delete(model: MetricDimension.self)
            try context.delete(model: MetricRollup.self)
            try context.delete(model: MetricDefinition.self)
            try context.save()
        } catch {
            // Best effort
        }
    }

    public func purge(olderThan date: Date) {
        buffer.removeAll { $0.timestamp < date }

        let context = modelContainer.mainContext
        let cutoff = date
        do {
            try context.delete(
                model: MetricObservation.self,
                where: #Predicate { $0.timestamp < cutoff }
            )
            try context.save()
        } catch {
            // Best effort
        }

        // Rebuild known identifiers
        knownIdentifiers = Set(buffer.map { MetricIdentifier(entry: $0) })
        let descriptor = FetchDescriptor<MetricDefinition>()
        if let defs = try? context.fetch(descriptor) {
            for def in defs {
                if let type = MetricType(rawValue: def.typeRawValue) {
                    knownIdentifiers.insert(
                        MetricIdentifier(
                            label: def.label, dimensions: [], type: type
                        ))
                }
            }
        }
    }

    public var entryCount: Int {
        let context = modelContainer.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<MetricObservation>())) ?? 0
        return count + buffer.count
    }

    // MARK: - Flushing

    /// The current unflushed buffer entries.
    var unflushedEntries: [MetricEntry] { buffer }

    /// Force-flush the current buffer to persistent storage.
    ///
    /// > Since: 0.7.0 — now `async`. Previously synchronous. Flush work runs on a
    /// > background actor with a dedicated `ModelContext`.
    public func flushNow() async {
        guard !buffer.isEmpty else { return }
        let entries = buffer
        buffer.removeAll()

        await flushWorker.flush(entries)
        NotificationCenter.default.post(name: .metricsStoreDidFlush, object: nil)
    }

    // MARK: - Private

    private func scheduleFlush() {
        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.flushInterval ?? 1.0))
                guard !Task.isCancelled else { break }
                await self?.flushNow()
            }
        }
    }

    private func combinePredicates(
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
}

// MARK: - FlushWorker

/// Background actor that performs SwiftData inserts with a dedicated `ModelContext`.
private actor FlushWorker {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func flush(_ entries: [MetricEntry]) {
        let context = ModelContext(modelContainer)

        for entry in entries {
            let observation = MetricObservation(entry: entry)
            context.insert(observation)

            // Upsert MetricDefinition
            let label = entry.label
            let typeRaw = entry.type.rawValue
            var defDescriptor = FetchDescriptor<MetricDefinition>(
                predicate: #Predicate { $0.label == label && $0.typeRawValue == typeRaw }
            )
            defDescriptor.fetchLimit = 1

            if let existing = try? context.fetch(defDescriptor).first {
                existing.lastSeenAt = entry.timestamp
                existing.totalObservations += 1
                let dimKeys = Set(entry.dimensions.map(\.0))
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
                let dimKeys = entry.dimensions.map(\.0)
                let json =
                    (try? JSONEncoder().encode(dimKeys))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
                let def = MetricDefinition(
                    label: entry.label,
                    typeRawValue: entry.type.rawValue,
                    knownDimensionKeysJSON: json,
                    firstSeenAt: entry.timestamp,
                    lastSeenAt: entry.timestamp,
                    totalObservations: 1
                )
                context.insert(def)
            }
        }

        try? context.save()
    }
}
