import Foundation

/// Protocol for metric entry storage backends.
///
/// Conforming types manage the persistence and retrieval of ``MetricEntry`` values.
/// The default implementation provided by this package is ``InMemoryMetricsStorage``.
@MainActor
public protocol MetricsStorage: Sendable {
    /// Record a new metric entry.
    func record(_ entry: MetricEntry)

    /// Query entries matching the given filters.
    func query(_ query: MetricsQuery) -> [MetricEntry]

    /// Compute summary statistics for a specific metric identifier.
    func summary(for identifier: MetricIdentifier) -> MetricSummary?

    /// All metric identifiers that have been recorded.
    func knownMetrics() -> [MetricIdentifier]

    /// Remove all stored entries.
    func clear()

    /// Remove entries older than the given date.
    func purge(olderThan date: Date)

    /// The total number of stored entries.
    var entryCount: Int { get }

    /// Returns the most recently recorded value for the given metric identifier.
    ///
    /// The default implementation falls back to ``summary(for:)``. Conforming types
    /// can override this for O(1) lookups.
    ///
    /// - Since: 0.6.0
    func latestValue(for identifier: MetricIdentifier) -> Double?
}

extension MetricsStorage {
    public func latestValue(for identifier: MetricIdentifier) -> Double? {
        summary(for: identifier)?.latest
    }
}
