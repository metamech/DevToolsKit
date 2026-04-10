import Foundation
import Testing

@testable import DevToolsKitMetrics

@Suite(.serialized)
@MainActor
struct MetricsManagerTests {
    @Test func filteredMetricsByType() {
        let store = InMemoryMetricsStorage()
        store.record(MetricEntry(label: "a", dimensions: [], type: .counter, value: 1))
        store.record(MetricEntry(label: "b", dimensions: [], type: .timer, value: 2))

        let manager = MetricsManager(storage: store)
        manager.filterType = .counter

        let filtered = manager.filteredMetrics
        #expect(filtered.count == 1)
        #expect(filtered[0].label == "a")
    }

    @Test func filteredMetricsBySearchText() {
        let store = InMemoryMetricsStorage()
        store.record(MetricEntry(label: "http.requests", dimensions: [], type: .counter, value: 1))
        store.record(MetricEntry(label: "db.queries", dimensions: [], type: .counter, value: 2))

        let manager = MetricsManager(storage: store)
        manager.searchText = "http"

        let filtered = manager.filteredMetrics
        #expect(filtered.count == 1)
        #expect(filtered[0].label == "http.requests")
    }

    @Test func totalEntries() {
        let store = InMemoryMetricsStorage()
        store.record(MetricEntry(label: "a", dimensions: [], type: .counter, value: 1))
        store.record(MetricEntry(label: "b", dimensions: [], type: .counter, value: 2))

        let manager = MetricsManager(storage: store)
        #expect(manager.totalEntries == 2)
    }

    @Test func clearDelegatesToStorage() async {
        let store = InMemoryMetricsStorage()
        store.record(MetricEntry(label: "test", dimensions: [], type: .counter, value: 1))

        let manager = MetricsManager(storage: store)
        #expect(manager.totalEntries == 1)

        await manager.clear()
        #expect(manager.totalEntries == 0)
    }

    @Test func latestValues() {
        let store = InMemoryMetricsStorage()
        store.record(MetricEntry(label: "test", dimensions: [], type: .counter, value: 10))
        store.record(MetricEntry(label: "test", dimensions: [], type: .counter, value: 20))

        let manager = MetricsManager(storage: store)
        let latest = manager.latestValues
        let identifier = MetricIdentifier(label: "test", dimensions: [], type: .counter)
        #expect(latest[identifier] == 20)
    }
}
