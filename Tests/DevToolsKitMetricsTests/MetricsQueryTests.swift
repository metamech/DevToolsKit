import Foundation
import Testing

@testable import DevToolsKitMetrics

@Suite(.serialized)
@MainActor
struct MetricsQueryTests {
    @Test func emptyQueryReturnsAll() {
        let store = InMemoryMetricsStorage()
        store.record(makeEntry(label: "a", type: .counter, value: 1))
        store.record(makeEntry(label: "b", type: .timer, value: 2))

        let results = store.query(MetricsQuery())
        #expect(results.count == 2)
    }

    @Test func combinedFilters() {
        let store = InMemoryMetricsStorage()
        store.record(makeEntry(label: "http.requests", dimensions: [("method", "GET")], type: .counter, value: 1))
        store.record(makeEntry(label: "http.requests", dimensions: [("method", "POST")], type: .counter, value: 2))
        store.record(makeEntry(label: "db.queries", dimensions: [("method", "GET")], type: .timer, value: 3))

        let results = store.query(MetricsQuery(
            label: "http.requests",
            type: .counter,
            dimensions: [("method", "GET")]
        ))
        #expect(results.count == 1)
        #expect(results[0].value == 1)
    }

    @Test func dateRangeFilter() {
        let store = InMemoryMetricsStorage()
        let now = Date()
        let hourAgo = now.addingTimeInterval(-3600)
        let twoHoursAgo = now.addingTimeInterval(-7200)
        let threeHoursAgo = now.addingTimeInterval(-10800)

        store.record(MetricEntry(timestamp: threeHoursAgo, label: "a", dimensions: [], type: .counter, value: 1))
        store.record(MetricEntry(timestamp: hourAgo, label: "b", dimensions: [], type: .counter, value: 2))
        store.record(MetricEntry(timestamp: now, label: "c", dimensions: [], type: .counter, value: 3))

        let results = store.query(MetricsQuery(
            startDate: twoHoursAgo,
            endDate: now.addingTimeInterval(-60)
        ))
        #expect(results.count == 1)
        #expect(results[0].label == "b")
    }

    @Test func aggregationSummarize() {
        let entries = (1...5).map { i in
            makeEntry(label: "test", type: .counter, value: Double(i))
        }
        let identifier = MetricIdentifier(label: "test", dimensions: [], type: .counter)

        let summary = MetricsAggregation.summarize(entries, identifier: identifier)
        #expect(summary != nil)
        #expect(summary?.count == 5)
        #expect(summary?.sum == 15)
        #expect(summary?.min == 1)
        #expect(summary?.max == 5)
        #expect(summary?.avg == 3)
        #expect(summary?.p50 == 3)
    }

    @Test func aggregationGroupByInterval() {
        let now = Date()
        let entries = (0..<6).map { i in
            MetricEntry(
                timestamp: now.addingTimeInterval(Double(i) * 30),
                label: "test",
                dimensions: [],
                type: .counter,
                value: Double(i)
            )
        }

        // Group by 60-second intervals
        let groups = MetricsAggregation.groupByInterval(entries, interval: 60)
        #expect(!groups.isEmpty)
        // All entries should be accounted for
        let totalCount = groups.reduce(0) { $0 + $1.count }
        #expect(totalCount == 6)
    }

    @Test func aggregationEmptyInput() {
        let identifier = MetricIdentifier(label: "test", dimensions: [], type: .counter)
        let summary = MetricsAggregation.summarize([], identifier: identifier)
        #expect(summary == nil)

        let groups = MetricsAggregation.groupByInterval([], interval: 60)
        #expect(groups.isEmpty)
    }

    // MARK: - Helpers

    private func makeEntry(
        label: String,
        dimensions: [(String, String)] = [],
        type: MetricType,
        value: Double
    ) -> MetricEntry {
        MetricEntry(label: label, dimensions: dimensions, type: type, value: value)
    }
}
