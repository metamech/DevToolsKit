import DevToolsKitMetrics
import Foundation
import SwiftData

/// Notification posted after each batch flush to the persistent store.
///
/// > Since: 0.3.0
extension Notification.Name {
    public static let metricsStoreDidFlush = Notification.Name("DevToolsKitMetricsStoreDidFlush")
}

// MARK: - RingBuffer

/// Fixed-capacity ring buffer that drops the oldest entry when full.
///
/// All mutations are value-typed and performed inside `BufferActor`.
private struct RingBuffer<T> {
    private var storage: [T?]
    private var head: Int = 0  // index of oldest entry
    private var _count: Int = 0
    private(set) var droppedCount: UInt64 = 0

    var capacity: Int { storage.count }
    var count: Int { _count }
    var isEmpty: Bool { _count == 0 }

    init(capacity: Int) {
        precondition(capacity > 0, "RingBuffer capacity must be positive")
        self.storage = [T?](repeating: nil, count: capacity)
    }

    /// Append an element. If full, overwrites the oldest entry and increments `droppedCount`.
    mutating func append(_ element: T) {
        if _count == capacity {
            // Overwrite oldest: head points to oldest, advance it
            storage[head] = element
            head = (head + 1) % capacity
            droppedCount += 1
        } else {
            let tail = (head + _count) % capacity
            storage[tail] = element
            _count += 1
        }
    }

    /// Drain all elements in FIFO order and reset the buffer.
    mutating func drain() -> [T] {
        guard _count > 0 else { return [] }
        var result: [T] = []
        result.reserveCapacity(_count)
        for i in 0..<_count {
            let index = (head + i) % capacity
            if let element = storage[index] {
                result.append(element)
            }
        }
        // Reset
        head = 0
        _count = 0
        // Zero out storage to release references
        for i in 0..<capacity { storage[i] = nil }
        return result
    }

    /// Non-destructive snapshot in FIFO order.
    func snapshot() -> [T] {
        guard _count > 0 else { return [] }
        var result: [T] = []
        result.reserveCapacity(_count)
        for i in 0..<_count {
            let index = (head + i) % capacity
            if let element = storage[index] {
                result.append(element)
            }
        }
        return result
    }
}

// MARK: - BufferActor

/// Actor that owns the ring buffer of pending `MetricEntry` values.
///
/// `PersistentMetricsStorage.record(_:)` is `nonisolated` and posts to this actor
/// via a fire-and-forget `Task`. All buffer mutations are serialized here, completely
/// off the main actor.
private actor BufferActor {
    private var ring: RingBuffer<MetricEntry>

    init(capacity: Int) {
        self.ring = RingBuffer(capacity: capacity)
    }

    /// Append a single entry to the ring buffer.
    func append(_ entry: MetricEntry) {
        ring.append(entry)
    }

    /// Drain all buffered entries and return them. Buffer is reset.
    func drain() -> [MetricEntry] {
        ring.drain()
    }

    /// Non-destructive snapshot of buffered entries (for query merge).
    func snapshot() -> [MetricEntry] {
        ring.snapshot()
    }

    /// Number of entries currently buffered.
    var pendingCount: Int { ring.count }

    /// Cumulative count of entries dropped due to buffer overflow since launch.
    var droppedSinceLaunch: UInt64 { ring.droppedCount }
}

// MARK: - PersistentMetricsStorage

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
/// ## Non-blocking emit (v0.15.0)
///
/// `record(_:)` is `nonisolated` and dispatches appends to an internal `BufferActor` via
/// fire-and-forget `Task`. The caller pays no actor hop — emit cost is on the order of
/// Task enqueue overhead (~microseconds). Overflow entries are dropped (oldest-first) and
/// counted in `droppedSinceLaunch`.
///
/// > Since: 0.3.0
/// > Breaking change in 0.7.0: `flushNow()` is now `async`.
/// > Breaking change in 0.11.0: `metricsActor` is now required; `FlushWorker` removed.
/// > API change in 0.15.0: `record(_:)` is now `nonisolated`; buffer moved off main actor.
@MainActor
@Observable
public final class PersistentMetricsStorage: MetricsStorage, Sendable {
    private let modelContainer: ModelContainer
    private let metricsActor: MetricsStoreActor
    private let batchSize: Int
    private let flushInterval: TimeInterval

    /// Actor-isolated ring buffer. All appends land here, off the main actor.
    @ObservationIgnored private let bufferActor: BufferActor

    /// Main-actor snapshot for synchronous `query()` merge. Updated on each drain.
    /// May lag a few microseconds behind `bufferActor`; acceptable for metrics use.
    private var recentSnapshot: [MetricEntry] = []

    @ObservationIgnored private nonisolated(unsafe) var flushTask: Task<Void, Never>?
    private var knownIdentifiers: Set<MetricIdentifier> = []

    // MARK: - Init

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
    ///   - bufferCapacity: Ring buffer capacity. Pass `0` to auto-derive as
    ///     `max(batchSize * 8, 4096)`. Defaults to `0`.
    public init(
        metricsActor: MetricsStoreActor,
        modelContainer: ModelContainer,
        batchSize: Int = 50,
        flushInterval: TimeInterval = 1.0,
        bufferCapacity: Int = 0
    ) {
        self.metricsActor = metricsActor
        self.modelContainer = modelContainer
        self.batchSize = batchSize
        self.flushInterval = flushInterval
        let effectiveCapacity = bufferCapacity > 0 ? bufferCapacity : max(batchSize * 8, 4096)
        self.bufferActor = BufferActor(capacity: effectiveCapacity)
        scheduleFlush()
    }

    deinit {
        flushTask?.cancel()
    }

    // MARK: - MetricsStorage

    /// Record a metric entry. This method is `nonisolated` and non-blocking.
    ///
    /// The entry is enqueued to a background `BufferActor` via a fire-and-forget `Task`.
    /// The caller takes no actor hop. When the buffer exceeds `batchSize`, a flush is
    /// scheduled automatically.
    ///
    /// > Note: `record(_:)` is intentionally fire-and-forget. If you need to observe
    /// > the entry immediately (e.g., in tests), call `await _testWaitForPendingAppends()`
    /// > before asserting.
    public nonisolated func record(_ entry: MetricEntry) {
        Task {
            await bufferActor.append(entry)
            let pending = await bufferActor.pendingCount
            if pending >= batchSize {
                await flushNow()
            }
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

        // Merge unflushed buffer (uses the main-actor snapshot — may lag microseconds)
        var buffered = recentSnapshot
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
        recentSnapshot.removeAll()
        knownIdentifiers.removeAll()
        // Drain bufferActor to discard pending entries
        _ = await bufferActor.drain()
        try? await metricsActor.clear()
    }

    public func purge(olderThan date: Date) async {
        recentSnapshot.removeAll { $0.timestamp < date }
        knownIdentifiers = Set(recentSnapshot.map { MetricIdentifier(entry: $0) })
        try? await metricsActor.purge(olderThan: date)
    }

    public var entryCount: Int {
        let context = modelContainer.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<MetricObservation>())) ?? 0
        return count + recentSnapshot.count
    }

    // MARK: - Flushing

    /// The current unflushed buffer entries (snapshot, may lag by microseconds).
    var unflushedEntries: [MetricEntry] { recentSnapshot }

    /// Force-flush the current buffer to persistent storage.
    ///
    /// > flushNow is intentionally async; never call it via a synchronous wrapper.
    /// > Since: 0.7.0 — now `async`. Previously synchronous.
    public func flushNow() async {
        // Take a snapshot for query() before draining
        recentSnapshot = await bufferActor.snapshot()

        let entries = await bufferActor.drain()
        guard !entries.isEmpty else { return }

        // Update knownIdentifiers and clear recentSnapshot (entries are now in flight to the actor)
        for entry in entries {
            knownIdentifiers.insert(MetricIdentifier(entry: entry))
        }
        recentSnapshot.removeAll()

        let dtos = entries.map { MetricObservationDTO(entry: $0) }
        try? await metricsActor.insertBatched(dtos)
        NotificationCenter.default.post(name: .metricsStoreDidFlush, object: nil)
    }

    // MARK: - Async state exposure

    /// The cumulative count of metric entries dropped due to buffer overflow since launch.
    ///
    /// > Since: 0.15.0
    public var droppedSinceLaunch: UInt64 {
        get async { await bufferActor.droppedSinceLaunch }
    }

    // MARK: - Test support

    /// Wait until all in-flight `record(_:)` fire-and-forget Tasks have delivered their
    /// entry to the `BufferActor`. Call this in tests before asserting on buffered state.
    ///
    /// Implementation: yield the cooperative executor enough times for all pending Tasks
    /// to start and enqueue their `append` calls onto the actor, then perform one
    /// actor call to flush the actor's serial queue. The loop bound (32) is
    /// conservative — a burst of 1 000 records will fan out into Tasks that each
    /// block on the actor's serial queue; 32 yields lets the executor service all
    /// of them before the final `pendingCount` synchronises.
    ///
    /// > Since: 0.15.0 (internal; not part of the public API contract)
    func _testWaitForPendingAppends() async {
        for _ in 0..<32 { await Task.yield() }
        // Synchronise with the actor: this call sits behind all prior append() calls
        // because the actor serializes its work queue.
        _ = await bufferActor.pendingCount
    }

    // MARK: - Private

    private func scheduleFlush() {
        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let interval = self.flushInterval
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                await self.flushNow()
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
