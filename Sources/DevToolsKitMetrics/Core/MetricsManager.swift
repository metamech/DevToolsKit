import Foundation

/// Central coordinator for the DevToolsKitMetrics module.
///
/// Holds a reference to the ``MetricsStorage`` and provides UI state
/// for filtering and searching metrics in the panel.
@MainActor
@Observable
public final class MetricsManager: Sendable {
    /// The backing storage for metric entries.
    public let storage: any MetricsStorage

    /// Current search text for filtering metrics in the UI.
    public var searchText: String = ""

    /// Filter by metric type in the UI.
    public var filterType: MetricType?

    /// Creates a manager with the given storage backend.
    ///
    /// - Parameter storage: The storage to use. Defaults to ``InMemoryMetricsStorage``.
    public init(storage: any MetricsStorage = InMemoryMetricsStorage()) {
        self.storage = storage
    }

    /// Known metrics filtered by current search text and type filter.
    public var filteredMetrics: [MetricIdentifier] {
        var metrics = storage.knownMetrics()

        if let filterType {
            metrics = metrics.filter { $0.type == filterType }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            metrics = metrics.filter { $0.label.lowercased().contains(query) }
        }

        return metrics.sorted { $0.label < $1.label }
    }

    /// Latest recorded value for each known metric.
    public var latestValues: [MetricIdentifier: Double] {
        var result: [MetricIdentifier: Double] = [:]
        for identifier in storage.knownMetrics() {
            if let value = storage.latestValue(for: identifier) {
                result[identifier] = value
            }
        }
        return result
    }

    /// Total number of entries across all metrics.
    public var totalEntries: Int {
        storage.entryCount
    }

    /// Clear all stored metrics.
    public func clear() async {
        await storage.clear()
    }

    /// Purge entries older than the given date.
    public func purge(olderThan date: Date) async {
        await storage.purge(olderThan: date)
    }
}
