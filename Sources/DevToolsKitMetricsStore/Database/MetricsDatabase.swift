import Foundation
import SwiftData
import DevToolsKitMetrics

/// High-level facade for querying the persistent metrics store.
///
/// Provides a rich query API including time-bucketed aggregation, streaming
/// updates, metric discovery, and rate-of-change calculations.
///
/// > Since: 0.3.0
@MainActor
@Observable
public final class MetricsDatabase: Sendable {
    private let storage: PersistentMetricsStorage
    private let modelContainer: ModelContainer

    /// Creates a database facade backed by the given storage and container.
    public init(storage: PersistentMetricsStorage, modelContainer: ModelContainer) {
        self.storage = storage
        self.modelContainer = modelContainer
    }

    /// Execute a ``DatabaseQuery`` and return the result.
    public func execute(_ query: DatabaseQuery) -> QueryResult {
        let context = modelContainer.mainContext
        do {
            return try QueryExecutor.execute(
                query, context: context,
                unflushedEntries: storage.unflushedEntries
            )
        } catch {
            return QueryResult(rows: [])
        }
    }

    /// Stream query results, re-executing on each flush.
    ///
    /// Emits an initial result immediately, then a new result after each
    /// ``Notification.Name.metricsStoreDidFlush`` notification.
    public func stream(_ query: DatabaseQuery) -> AsyncStream<QueryResult> {
        AsyncStream { continuation in
            // Emit initial result
            let initial = self.execute(query)
            continuation.yield(initial)

            let task = Task { @MainActor [weak self] in
                let notifications = NotificationCenter.default.notifications(
                    named: .metricsStoreDidFlush
                )
                for await _ in notifications {
                    guard !Task.isCancelled else { break }
                    guard let self else { break }
                    let result = self.execute(query)
                    continuation.yield(result)
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Discover known metrics, optionally filtered by label prefix.
    public func discover(prefix: String? = nil) -> [MetricDefinition] {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<MetricDefinition>(
            sortBy: [SortDescriptor(\.label)]
        )
        let definitions = (try? context.fetch(descriptor)) ?? []

        if let prefix {
            return definitions.filter { $0.label.hasPrefix(prefix) }
        }
        return definitions
    }

    /// Compute summary statistics for a specific metric.
    public func summary(for label: String, type: MetricType? = nil) -> MetricSummary? {
        let entries: [MetricEntry]
        if let type {
            entries = storage.query(MetricsQuery(label: label, type: type))
        } else {
            entries = storage.query(MetricsQuery(label: label))
        }

        guard !entries.isEmpty else { return nil }

        let identifier = MetricIdentifier(
            label: label,
            dimensions: [],
            type: type ?? entries.first!.type
        )
        return MetricsAggregation.summarize(entries, identifier: identifier)
    }

    /// Calculate the rate of change per second for a metric over the given interval.
    ///
    /// - Parameters:
    ///   - label: The metric label.
    ///   - interval: The time window to measure rate over.
    /// - Returns: The rate (change per second), or `nil` if insufficient data.
    public func rate(label: String, over interval: TimeInterval) -> Double? {
        let now = Date()
        let start = now.addingTimeInterval(-interval)

        let entries = storage.query(MetricsQuery(
            label: label,
            startDate: start,
            endDate: now,
            sort: .timestampAscending
        ))

        guard let first = entries.first, let last = entries.last,
              entries.count >= 2
        else { return nil }

        let timeDelta = last.timestamp.timeIntervalSince(first.timestamp)
        guard timeDelta > 0 else { return nil }

        let valueDelta = last.value - first.value
        return valueDelta / timeDelta
    }
}
