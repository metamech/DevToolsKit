import Foundation
import SwiftData
import Testing

@testable import DevToolsKitMetrics
@testable import DevToolsKitMetricsStore

@Suite(.serialized)
@MainActor
struct PersistentMetricsStorageTests {
    private func makeStorage(batchSize: Int = 100) throws -> PersistentMetricsStorage {
        let schema = Schema(MetricsModelTypes.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return PersistentMetricsStorage(
            modelContainer: container,
            batchSize: batchSize,
            flushInterval: 60  // long interval so we control flushing manually
        )
    }

    @Test
    func recordAndQueryAfterFlush() async throws {
        let storage = try makeStorage()

        let entry = MetricEntry(
            label: "test.metric",
            dimensions: [("env", "test")],
            type: .counter,
            value: 10.0
        )
        storage.record(entry)
        await storage.flushNow()

        // Give SwiftData a moment to persist
        let results = storage.query(MetricsQuery(label: "test.metric"))
        #expect(results.count == 1)
        #expect(results[0].label == "test.metric")
        #expect(results[0].value == 10.0)
    }

    @Test
    func queryUnflushedBuffer() throws {
        let storage = try makeStorage()

        let entry = MetricEntry(
            label: "buffered",
            dimensions: [],
            type: .counter,
            value: 5.0
        )
        storage.record(entry)
        // Don't flush — should still be queryable from buffer

        let results = storage.query(MetricsQuery(label: "buffered"))
        #expect(results.count == 1)
        #expect(results[0].value == 5.0)
    }

    @Test
    func batchFlushTriggersAtBatchSize() async throws {
        let storage = try makeStorage(batchSize: 3)

        for i in 0..<3 {
            storage.record(
                MetricEntry(
                    label: "batch",
                    dimensions: [],
                    type: .counter,
                    value: Double(i)
                ))
        }

        // The batch-size flush is now async — give it a moment
        try await Task.sleep(for: .milliseconds(100))

        // Query should still return all 3
        let results = storage.query(MetricsQuery(label: "batch"))
        #expect(results.count == 3)
    }

    @Test
    func queryWithTypeFilter() throws {
        let storage = try makeStorage()

        storage.record(MetricEntry(label: "m", dimensions: [], type: .counter, value: 1))
        storage.record(MetricEntry(label: "m", dimensions: [], type: .timer, value: 2))

        let counters = storage.query(MetricsQuery(label: "m", type: .counter))
        #expect(counters.count == 1)
        #expect(counters[0].type == .counter)
    }

    @Test
    func queryWithDateRange() throws {
        let storage = try makeStorage()
        let now = Date()

        storage.record(
            MetricEntry(
                timestamp: now.addingTimeInterval(-100),
                label: "t", dimensions: [], type: .counter, value: 1
            ))
        storage.record(
            MetricEntry(
                timestamp: now.addingTimeInterval(-50),
                label: "t", dimensions: [], type: .counter, value: 2
            ))
        storage.record(
            MetricEntry(
                timestamp: now,
                label: "t", dimensions: [], type: .counter, value: 3
            ))

        let results = storage.query(
            MetricsQuery(
                label: "t",
                startDate: now.addingTimeInterval(-75),
                endDate: now.addingTimeInterval(-25)
            ))
        #expect(results.count == 1)
        #expect(results[0].value == 2)
    }

    @Test
    func queryWithDimensionFilter() throws {
        let storage = try makeStorage()

        storage.record(MetricEntry(label: "d", dimensions: [("env", "prod")], type: .counter, value: 1))
        storage.record(MetricEntry(label: "d", dimensions: [("env", "dev")], type: .counter, value: 2))

        let results = storage.query(
            MetricsQuery(
                label: "d",
                dimensions: [("env", "prod")]
            ))
        #expect(results.count == 1)
        #expect(results[0].value == 1)
    }

    @Test
    func queryWithSorting() throws {
        let storage = try makeStorage()

        storage.record(MetricEntry(label: "s", dimensions: [], type: .counter, value: 3))
        storage.record(MetricEntry(label: "s", dimensions: [], type: .counter, value: 1))
        storage.record(MetricEntry(label: "s", dimensions: [], type: .counter, value: 2))

        let ascending = storage.query(MetricsQuery(label: "s", sort: .valueAscending))
        #expect(ascending.map(\.value) == [1, 2, 3])

        let descending = storage.query(MetricsQuery(label: "s", sort: .valueDescending))
        #expect(descending.map(\.value) == [3, 2, 1])
    }

    @Test
    func queryWithLimit() throws {
        let storage = try makeStorage()

        for i in 0..<10 {
            storage.record(MetricEntry(label: "l", dimensions: [], type: .counter, value: Double(i)))
        }

        let results = storage.query(MetricsQuery(label: "l", limit: 3))
        #expect(results.count == 3)
    }

    @Test
    func knownMetrics() throws {
        let storage = try makeStorage()

        storage.record(MetricEntry(label: "a", dimensions: [], type: .counter, value: 1))
        storage.record(MetricEntry(label: "b", dimensions: [], type: .timer, value: 2))
        storage.record(MetricEntry(label: "a", dimensions: [], type: .counter, value: 3))

        let known = storage.knownMetrics()
        #expect(known.count == 2)
        #expect(known.contains { $0.label == "a" && $0.type == .counter })
        #expect(known.contains { $0.label == "b" && $0.type == .timer })
    }

    @Test
    func summary() throws {
        let storage = try makeStorage()

        storage.record(MetricEntry(label: "sum", dimensions: [], type: .counter, value: 10))
        storage.record(MetricEntry(label: "sum", dimensions: [], type: .counter, value: 20))
        storage.record(MetricEntry(label: "sum", dimensions: [], type: .counter, value: 30))

        let id = MetricIdentifier(label: "sum", dimensions: [], type: .counter)
        let summary = storage.summary(for: id)
        #expect(summary != nil)
        #expect(summary?.count == 3)
        #expect(summary?.sum == 60)
        #expect(summary?.min == 10)
        #expect(summary?.max == 30)
        #expect(summary?.avg == 20)
    }

    @Test
    func clear() async throws {
        let storage = try makeStorage()

        storage.record(MetricEntry(label: "c", dimensions: [], type: .counter, value: 1))
        await storage.flushNow()

        storage.clear()

        #expect(storage.entryCount == 0)
        #expect(storage.knownMetrics().isEmpty)
    }

    @Test
    func entryCount() throws {
        let storage = try makeStorage()
        #expect(storage.entryCount == 0)

        storage.record(MetricEntry(label: "n", dimensions: [], type: .counter, value: 1))
        storage.record(MetricEntry(label: "n", dimensions: [], type: .counter, value: 2))
        #expect(storage.entryCount == 2)
    }
}
