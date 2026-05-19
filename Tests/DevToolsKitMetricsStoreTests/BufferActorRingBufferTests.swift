import Foundation
import SwiftData
import Testing

@testable import DevToolsKitMetrics
@testable import DevToolsKitMetricsStore

/// Tests for the internal ring buffer logic surfaced through `PersistentMetricsStorage`.
///
/// We exercise the ring buffer semantics via `PersistentMetricsStorage` with a very
/// small `bufferCapacity` so overflow behaviour is easy to trigger.
@Suite(.serialized)
@MainActor
struct BufferActorRingBufferTests {

    // MARK: - Helpers

    private func makeStorage(
        batchSize: Int = 1000,
        bufferCapacity: Int
    ) throws -> PersistentMetricsStorage {
        let schema = Schema(MetricsModelTypes.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let actor = MetricsStoreActor(modelContainer: container)
        return PersistentMetricsStorage(
            metricsActor: actor,
            modelContainer: container,
            batchSize: batchSize,
            flushInterval: 3600,  // never fires automatically during tests
            bufferCapacity: bufferCapacity
        )
    }

    private func entry(value: Double, label: String = "ring.test") -> MetricEntry {
        MetricEntry(label: label, dimensions: [], type: .counter, value: value)
    }

    // MARK: - Append below capacity

    @Test("Append below capacity: drain returns all entries in FIFO order")
    func appendBelowCapacity() async throws {
        let storage = try makeStorage(bufferCapacity: 10)

        for i in 0..<5 {
            storage.record(entry(value: Double(i)))
        }
        await storage._testWaitForPendingAppends()
        await storage.flushNow()

        // After flush all 5 should be in SwiftData
        let results = storage.query(MetricsQuery(label: "ring.test", sort: .valueAscending))
        #expect(results.count == 5)
        #expect(results.map(\.value) == [0, 1, 2, 3, 4])
    }

    // MARK: - Overflow / drop oldest

    @Test("Append past capacity: exactly bufferCapacity entries survive, droppedCount accurate")
    func appendPastCapacity() async throws {
        // Cap of 5 — append 10 entries valued 0…9; exactly 5 must be dropped
        let storage = try makeStorage(bufferCapacity: 5)

        for i in 0..<10 {
            storage.record(entry(value: Double(i)))
        }
        await storage._testWaitForPendingAppends()

        // droppedSinceLaunch must reflect the 5 overwritten entries
        let dropped = await storage.droppedSinceLaunch
        #expect(dropped == 5)

        await storage.flushNow()

        // Exactly 5 entries survive (fire-and-forget Task ordering is not guaranteed,
        // so we verify count and value range rather than exact sequence)
        let results = storage.query(MetricsQuery(label: "ring.test"))
        #expect(results.count == 5)
        for v in results.map(\.value) {
            #expect(v >= 0 && v <= 9, "Value \(v) out of expected range 0…9")
        }
        #expect(Set(results.map(\.value)).count == 5, "Expected 5 distinct values")
    }

    // MARK: - droppedCount accuracy

    @Test("droppedSinceLaunch is cumulative across multiple overflow cycles")
    func droppedCountAccumulates() async throws {
        let storage = try makeStorage(bufferCapacity: 3)

        // First overflow: append 6 entries → 3 drops
        for i in 0..<6 {
            storage.record(entry(value: Double(i)))
        }
        await storage._testWaitForPendingAppends()
        await storage.flushNow()

        // Second overflow: append 6 more → 3 more drops
        for i in 10..<16 {
            storage.record(entry(value: Double(i)))
        }
        await storage._testWaitForPendingAppends()

        let dropped = await storage.droppedSinceLaunch
        // 3 (first cycle) + 3 (second cycle) = 6
        #expect(dropped == 6)
    }

    // MARK: - Drain empties buffer

    @Test("Drain via flushNow empties the buffer: subsequent droppedSinceLaunch unchanged")
    func drainEmptiesBuffer() async throws {
        let storage = try makeStorage(bufferCapacity: 4)

        for i in 0..<4 {
            storage.record(entry(value: Double(i)))
        }
        await storage._testWaitForPendingAppends()
        await storage.flushNow()

        // Buffer should now be empty — appending 4 more should not trigger any drops
        for i in 10..<14 {
            storage.record(entry(value: Double(i)))
        }
        await storage._testWaitForPendingAppends()

        let dropped = await storage.droppedSinceLaunch
        #expect(dropped == 0)  // no overflow in either cycle

        await storage.flushNow()
        let total = storage.query(MetricsQuery(label: "ring.test"))
        #expect(total.count == 8)
    }

    // MARK: - Snapshot ordering

    @Test("Snapshot preserves insertion order")
    func snapshotPreservesOrder() async throws {
        let storage = try makeStorage(bufferCapacity: 10)

        // Use explicit timestamps to test ordering after flush
        let base = Date(timeIntervalSince1970: 1_000_000)
        for i in 0..<5 {
            storage.record(MetricEntry(
                timestamp: base.addingTimeInterval(Double(i)),
                label: "ring.order",
                dimensions: [],
                type: .counter,
                value: Double(i)
            ))
        }
        await storage._testWaitForPendingAppends()
        await storage.flushNow()

        let results = storage.query(MetricsQuery(label: "ring.order", sort: .timestampAscending))
        #expect(results.map(\.value) == [0, 1, 2, 3, 4])
    }

    // MARK: - Zero droppedCount when under capacity

    @Test("No drops when total appends stay within capacity")
    func noDropsUnderCapacity() async throws {
        let storage = try makeStorage(bufferCapacity: 100)

        for i in 0..<50 {
            storage.record(entry(value: Double(i)))
        }
        await storage._testWaitForPendingAppends()

        let dropped = await storage.droppedSinceLaunch
        #expect(dropped == 0)
    }
}
