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

    /// Creates an in-memory store with the given capacity.
    ///
    /// - Parameter maxEntries: Maximum entries before FIFO eviction. Defaults to 10,000.
    public init(maxEntries: Int = 10_000) {
        self.maxEntries = maxEntries
    }

    public func record(_ entry: MetricEntry) {
        entries.append(entry)
        knownIdentifiers.insert(MetricIdentifier(entry: entry))
        if entries.count > maxEntries {
            let overflow = entries.count - maxEntries
            entries.removeFirst(overflow)
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
        let matching = entries.filter { MetricIdentifier(entry: $0) == identifier }
        return MetricsAggregation.summarize(matching, identifier: identifier)
    }

    public func knownMetrics() -> [MetricIdentifier] {
        Array(knownIdentifiers)
    }

    public func clear() {
        entries.removeAll()
        knownIdentifiers.removeAll()
    }

    public func purge(olderThan date: Date) {
        entries.removeAll { $0.timestamp < date }
        // Rebuild known identifiers from remaining entries
        knownIdentifiers = Set(entries.map { MetricIdentifier(entry: $0) })
    }

    public var entryCount: Int {
        entries.count
    }
}
