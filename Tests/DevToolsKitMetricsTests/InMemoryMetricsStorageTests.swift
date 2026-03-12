import Foundation
import Testing

@testable import DevToolsKitMetrics

@Suite(.serialized)
@MainActor
struct InMemoryMetricsStorageTests {
    @Test func recordAndCount() {
        let store = InMemoryMetricsStorage()
        #expect(store.entryCount == 0)

        store.record(makeEntry(label: "test", type: .counter, value: 1))
        #expect(store.entryCount == 1)

        store.record(makeEntry(label: "test", type: .counter, value: 2))
        #expect(store.entryCount == 2)
    }

    @Test func fifoEviction() {
        let store = InMemoryMetricsStorage(maxEntries: 3)

        store.record(makeEntry(label: "a", type: .counter, value: 1))
        store.record(makeEntry(label: "b", type: .counter, value: 2))
        store.record(makeEntry(label: "c", type: .counter, value: 3))
        store.record(makeEntry(label: "d", type: .counter, value: 4))

        #expect(store.entryCount == 3)

        let all = store.query(MetricsQuery(sort: .timestampAscending))
        #expect(all[0].label == "b")
        #expect(all[2].label == "d")
    }

    @Test func queryFilterByLabel() {
        let store = InMemoryMetricsStorage()
        store.record(makeEntry(label: "http.requests", type: .counter, value: 1))
        store.record(makeEntry(label: "db.queries", type: .counter, value: 2))

        let results = store.query(MetricsQuery(label: "http.requests"))
        #expect(results.count == 1)
        #expect(results[0].label == "http.requests")
    }

    @Test func queryFilterByType() {
        let store = InMemoryMetricsStorage()
        store.record(makeEntry(label: "a", type: .counter, value: 1))
        store.record(makeEntry(label: "b", type: .timer, value: 2))

        let results = store.query(MetricsQuery(type: .timer))
        #expect(results.count == 1)
        #expect(results[0].type == .timer)
    }

    @Test func queryFilterByDimensions() {
        let store = InMemoryMetricsStorage()
        store.record(makeEntry(label: "a", dimensions: [("env", "prod")], type: .counter, value: 1))
        store.record(makeEntry(label: "a", dimensions: [("env", "dev")], type: .counter, value: 2))

        let results = store.query(MetricsQuery(dimensions: [("env", "prod")]))
        #expect(results.count == 1)
        #expect(results[0].value == 1)
    }

    @Test func queryFilterByDateRange() {
        let store = InMemoryMetricsStorage()
        let now = Date()
        let hourAgo = now.addingTimeInterval(-3600)
        let twoHoursAgo = now.addingTimeInterval(-7200)

        store.record(MetricEntry(timestamp: twoHoursAgo, label: "old", dimensions: [], type: .counter, value: 1))
        store.record(MetricEntry(timestamp: now, label: "new", dimensions: [], type: .counter, value: 2))

        let results = store.query(MetricsQuery(startDate: hourAgo))
        #expect(results.count == 1)
        #expect(results[0].label == "new")
    }

    @Test func querySortByValue() {
        let store = InMemoryMetricsStorage()
        store.record(makeEntry(label: "a", type: .counter, value: 3))
        store.record(makeEntry(label: "b", type: .counter, value: 1))
        store.record(makeEntry(label: "c", type: .counter, value: 2))

        let ascending = store.query(MetricsQuery(sort: .valueAscending))
        #expect(ascending[0].value == 1)
        #expect(ascending[2].value == 3)

        let descending = store.query(MetricsQuery(sort: .valueDescending))
        #expect(descending[0].value == 3)
        #expect(descending[2].value == 1)
    }

    @Test func queryWithLimit() {
        let store = InMemoryMetricsStorage()
        for i in 0..<10 {
            store.record(makeEntry(label: "test", type: .counter, value: Double(i)))
        }

        let results = store.query(MetricsQuery(limit: 3))
        #expect(results.count == 3)
    }

    @Test func summaryComputation() {
        let store = InMemoryMetricsStorage()
        let identifier = MetricIdentifier(label: "test", dimensions: [], type: .counter)

        store.record(makeEntry(label: "test", type: .counter, value: 10))
        store.record(makeEntry(label: "test", type: .counter, value: 20))
        store.record(makeEntry(label: "test", type: .counter, value: 30))

        let summary = store.summary(for: identifier)
        #expect(summary != nil)
        #expect(summary?.count == 3)
        #expect(summary?.sum == 60)
        #expect(summary?.min == 10)
        #expect(summary?.max == 30)
        #expect(summary?.avg == 20)
    }

    @Test func knownMetrics() {
        let store = InMemoryMetricsStorage()
        store.record(makeEntry(label: "a", type: .counter, value: 1))
        store.record(makeEntry(label: "b", type: .timer, value: 2))
        store.record(makeEntry(label: "a", type: .counter, value: 3))

        let known = store.knownMetrics()
        #expect(known.count == 2)
    }

    @Test func clear() {
        let store = InMemoryMetricsStorage()
        store.record(makeEntry(label: "test", type: .counter, value: 1))
        #expect(store.entryCount == 1)

        store.clear()
        #expect(store.entryCount == 0)
        #expect(store.knownMetrics().isEmpty)
    }

    @Test func purge() {
        let store = InMemoryMetricsStorage()
        let now = Date()
        let hourAgo = now.addingTimeInterval(-3600)

        store.record(MetricEntry(timestamp: hourAgo, label: "old", dimensions: [], type: .counter, value: 1))
        store.record(MetricEntry(timestamp: now, label: "new", dimensions: [], type: .counter, value: 2))

        store.purge(olderThan: now.addingTimeInterval(-1800))
        #expect(store.entryCount == 1)
        #expect(store.knownMetrics().count == 1)
    }

    // MARK: - latestValue(for:)

    @Test func latestValueReturnsCorrectValueAfterMultipleRecords() {
        let store = InMemoryMetricsStorage()
        let identifier = MetricIdentifier(label: "test", dimensions: [], type: .counter)

        store.record(makeEntry(label: "test", type: .counter, value: 1))
        store.record(makeEntry(label: "test", type: .counter, value: 5))
        store.record(makeEntry(label: "test", type: .counter, value: 3))

        #expect(store.latestValue(for: identifier) == 3)
    }

    @Test func latestValueReturnsNilForUnknownIdentifier() {
        let store = InMemoryMetricsStorage()
        let unknown = MetricIdentifier(label: "nonexistent", dimensions: [], type: .counter)

        #expect(store.latestValue(for: unknown) == nil)
    }

    @Test func latestValueCorrectAfterFIFOEviction() {
        let store = InMemoryMetricsStorage(maxEntries: 3)
        let idA = MetricIdentifier(label: "a", dimensions: [], type: .counter)
        let idB = MetricIdentifier(label: "b", dimensions: [], type: .counter)

        store.record(makeEntry(label: "a", type: .counter, value: 10))
        store.record(makeEntry(label: "a", type: .counter, value: 20))
        store.record(makeEntry(label: "b", type: .counter, value: 30))
        // Store is full: [a=10, a=20, b=30]
        store.record(makeEntry(label: "b", type: .counter, value: 40))
        // After eviction: [a=20, b=30, b=40]

        #expect(store.latestValue(for: idA) == 20)
        #expect(store.latestValue(for: idB) == 40)

        // Verify summary uses index too
        let summaryA = store.summary(for: idA)
        #expect(summaryA?.count == 1)
        #expect(summaryA?.latest == 20)
    }

    @Test func indexCorrectAfterPurge() {
        let store = InMemoryMetricsStorage()
        let now = Date()
        let hourAgo = now.addingTimeInterval(-3600)
        let id = MetricIdentifier(label: "test", dimensions: [], type: .counter)

        store.record(MetricEntry(timestamp: hourAgo, label: "test", dimensions: [], type: .counter, value: 1))
        store.record(MetricEntry(timestamp: now, label: "test", dimensions: [], type: .counter, value: 2))

        store.purge(olderThan: now.addingTimeInterval(-1800))

        #expect(store.latestValue(for: id) == 2)
        let summary = store.summary(for: id)
        #expect(summary?.count == 1)
    }

    @Test func indexCorrectAfterClear() {
        let store = InMemoryMetricsStorage()
        let id = MetricIdentifier(label: "test", dimensions: [], type: .counter)

        store.record(makeEntry(label: "test", type: .counter, value: 42))
        #expect(store.latestValue(for: id) == 42)

        store.clear()
        #expect(store.latestValue(for: id) == nil)
    }

    @Test func performanceManyEntriesAcrossMetrics() {
        let store = InMemoryMetricsStorage(maxEntries: 20_000)

        // Record 10k entries across 100 metrics
        for i in 0..<10_000 {
            let label = "metric.\(i % 100)"
            store.record(makeEntry(label: label, type: .counter, value: Double(i)))
        }

        // Verify latestValue is fast (O(1) per metric)
        for m in 0..<100 {
            let id = MetricIdentifier(label: "metric.\(m)", dimensions: [], type: .counter)
            let value = store.latestValue(for: id)
            #expect(value != nil)
        }

        // Verify summary uses the index (O(K) not O(N))
        let id = MetricIdentifier(label: "metric.0", dimensions: [], type: .counter)
        let summary = store.summary(for: id)
        #expect(summary?.count == 100) // 10000 / 100 metrics
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
