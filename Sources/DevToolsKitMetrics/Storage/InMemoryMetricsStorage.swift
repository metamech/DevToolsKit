import Foundation

/// FIFO in-memory storage for metric entries.
///
/// Entries exceeding ``maxEntries`` are evicted oldest-first. This is the default
/// storage backend for ``MetricsManager``.
@MainActor
@Observable
public final class InMemoryMetricsStorage: MetricsStorage, Sendable {
    /// Maximum number of entries to retain.
    public let maxEntries: Int

    private var entries: [MetricEntry] = []
    private var knownIdentifiers: Set<MetricIdentifier> = []

    // Per-identifier index for O(K) summary lookups instead of O(N) linear scans.
    @ObservationIgnored private var entriesByIdentifier: [MetricIdentifier: [MetricEntry]] = [:]
    // Cached latest value per metric for O(1) lookups.
    @ObservationIgnored private var cachedLatestValues: [MetricIdentifier: Double] = [:]

    /// Creates an in-memory store with the given capacity.
    ///
    /// - Parameter maxEntries: Maximum entries before FIFO eviction. Defaults to 10,000.
    public init(maxEntries: Int = 10_000) {
        self.maxEntries = maxEntries
    }

    public func record(_ entry: MetricEntry) {
        entries.append(entry)
        let identifier = MetricIdentifier(entry: entry)
        knownIdentifiers.insert(identifier)
        entriesByIdentifier[identifier, default: []].append(entry)
        cachedLatestValues[identifier] = entry.value

        if entries.count > maxEntries {
            let overflow = entries.count - maxEntries
            let evicted = entries.prefix(overflow)
            entries.removeFirst(overflow)

            // Remove evicted entries from per-identifier index
            var evictedByIdentifier: [MetricIdentifier: Int] = [:]
            for entry in evicted {
                let id = MetricIdentifier(entry: entry)
                evictedByIdentifier[id, default: 0] += 1
            }
            for (id, count) in evictedByIdentifier {
                if var indexed = entriesByIdentifier[id] {
                    indexed.removeFirst(min(count, indexed.count))
                    if indexed.isEmpty {
                        entriesByIdentifier.removeValue(forKey: id)
                    } else {
                        entriesByIdentifier[id] = indexed
                    }
                }
            }
        }
    }

    public func query(_ query: MetricsQuery) -> [MetricEntry] {
        var result = entries

        if let label = query.label {
            result = result.filter { $0.label == label }
        }
        if let type = query.type {
            result = result.filter { $0.type == type }
        }
        if let requiredDimensions = query.dimensions {
            result = result.filter { entry in
                requiredDimensions.allSatisfy { req in
                    entry.dimensions.contains { $0.0 == req.0 && $0.1 == req.1 }
                }
            }
        }
        if let startDate = query.startDate {
            result = result.filter { $0.timestamp >= startDate }
        }
        if let endDate = query.endDate {
            result = result.filter { $0.timestamp <= endDate }
        }

        switch query.sort {
        case .timestampAscending:
            result.sort { $0.timestamp < $1.timestamp }
        case .timestampDescending:
            result.sort { $0.timestamp > $1.timestamp }
        case .valueAscending:
            result.sort { $0.value < $1.value }
        case .valueDescending:
            result.sort { $0.value > $1.value }
        }

        if let limit = query.limit {
            result = Array(result.prefix(limit))
        }

        return result
    }

    public func summary(for identifier: MetricIdentifier) -> MetricSummary? {
        let matching = entriesByIdentifier[identifier] ?? []
        return MetricsAggregation.summarize(matching, identifier: identifier)
    }

    public func latestValue(for identifier: MetricIdentifier) -> Double? {
        cachedLatestValues[identifier]
    }

    public func knownMetrics() -> [MetricIdentifier] {
        Array(knownIdentifiers)
    }

    public func clear() async {
        entries.removeAll()
        knownIdentifiers.removeAll()
        entriesByIdentifier.removeAll()
        cachedLatestValues.removeAll()
    }

    public func purge(olderThan date: Date) async {
        entries.removeAll { $0.timestamp < date }
        // Rebuild indexes from remaining entries
        knownIdentifiers = Set(entries.map { MetricIdentifier(entry: $0) })
        rebuildIndexes()
    }

    public var entryCount: Int {
        entries.count
    }

    // MARK: - Private

    private func rebuildIndexes() {
        entriesByIdentifier.removeAll()
        cachedLatestValues.removeAll()
        for entry in entries {
            let id = MetricIdentifier(entry: entry)
            entriesByIdentifier[id, default: []].append(entry)
            cachedLatestValues[id] = entry.value
        }
    }
}
