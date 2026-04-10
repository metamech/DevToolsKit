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
/// Records are buffered and flushed in batches for performance. All SwiftData **writes**
/// are serialized through the injected ``MetricsStoreActor``, eliminating the concurrent-
/// context data races that caused `EXC_BREAKPOINT` crashes (#1460).
///
/// Synchronous **reads** (`query()`, `entryCount`, `knownMetrics()`, `clear()`, `purge()`)
/// use `modelContainer.mainContext`, which is always accessed on the main actor. This is
/// safe because the crash path was background-context writes racing background-context reads
/// — the main context was not a participant in that race.
///
/// > Since: 0.3.0
/// > Breaking change in 0.7.0: `flushNow()` is now `async`.
/// > Breaking change in 0.11.0: `metricsActor` is now required; `FlushWorker` removed.
@MainActor
@Observable
public final class PersistentMetricsStorage: MetricsStorage, Sendable {
    private let modelContainer: ModelContainer
    private let metricsActor: MetricsStoreActor
    private let batchSize: Int
    private let flushInterval: TimeInterval
    private var buffer: [MetricEntry] = []
    @ObservationIgnored private nonisolated(unsafe) var flushTask: Task<Void, Never>?
    private var knownIdentifiers: Set<MetricIdentifier> = []

    /// Creates a persistent storage backed by the given actor.
    ///
    /// - Parameters:
    ///   - metricsActor: All SwiftData **writes** are serialized through this actor's
    ///     single `ModelContext`. Must be the same actor shared by ``MetricsDatabase``
    ///     and ``RetentionEngine``, and must be backed by `modelContainer`.
    ///   - modelContainer: The SwiftData container. Used for synchronous `mainContext`
    ///     reads. Must be the same container the actor was created with.
    ///   - batchSize: Number of entries to buffer before flushing. Defaults to 50.
    ///   - flushInterval: Maximum seconds between flushes. Defaults to 1.0.
    public init(
        metricsActor: MetricsStoreActor,
        modelContainer: ModelContainer,
        batchSize: Int = 50,
        flushInterval: TimeInterval = 1.0
    ) {
        self.metricsActor = metricsActor
        self.modelContainer = modelContainer
        self.batchSize = batchSize
        self.flushInterval = flushInterval
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

    public func clear() async {
        buffer.removeAll()
        knownIdentifiers.removeAll()
        try? await metricsActor.clear()
    }

    public func purge(olderThan date: Date) async {
        buffer.removeAll { $0.timestamp < date }
        knownIdentifiers = Set(buffer.map { MetricIdentifier(entry: $0) })
        try? await metricsActor.purge(olderThan: date)
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
    /// > Since: 0.7.0 — now `async`. Previously synchronous.
    public func flushNow() async {
        guard !buffer.isEmpty else { return }
        let entries = buffer
        buffer.removeAll()

        let dtos = entries.map { MetricObservationDTO(entry: $0) }
        try? await metricsActor.insert(dtos)
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
