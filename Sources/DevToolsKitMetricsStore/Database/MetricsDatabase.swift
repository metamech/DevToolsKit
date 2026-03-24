import DevToolsKitMetrics
import Foundation
import SwiftData

/// High-level facade for querying the persistent metrics store.
///
/// Provides a rich query API including time-bucketed aggregation, streaming
/// updates, metric discovery, and rate-of-change calculations.
///
/// > Since: 0.3.0
/// > Breaking change in 0.7.0: `execute()` is now `async`.
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
    ///
    /// Query execution runs on a background context for heavy fetches and aggregation.
    ///
    /// > Since: 0.7.0 — now `async`. Previously synchronous.
    public func execute(_ query: DatabaseQuery) async -> QueryResult {
        do {
            return try await QueryExecutor.execute(
                query, modelContainer: modelContainer,
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
            let initial = Task { @MainActor [weak self] in
                guard let self else { return }
                let result = await self.execute(query)
                continuation.yield(result)
            }

            let task = Task { @MainActor [weak self] in
                _ = await initial.value
                let notifications = NotificationCenter.default.notifications(
                    named: .metricsStoreDidFlush
                )
                for await _ in notifications {
                    guard !Task.isCancelled else { break }
                    guard let self else { break }
                    let result = await self.execute(query)
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

        guard let firstEntry = entries.first else { return nil }

        let identifier = MetricIdentifier(
            label: label,
            dimensions: [],
            type: type ?? firstEntry.type
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

        let entries = storage.query(
            MetricsQuery(
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
