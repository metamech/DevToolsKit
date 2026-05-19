import Foundation
import SwiftData
import Testing

@testable import DevToolsKitMetrics
@testable import DevToolsKitMetricsStore

/// Tests that verify the drop-oldest ring-buffer behaviour when the buffer overflows
/// while no flush is in progress.
@Suite(.serialized)
@MainActor
struct PersistentMetricsStorageDropTests {

    // MARK: - Helpers

    private func makeStorage(bufferCapacity: Int) throws -> PersistentMetricsStorage {
        let schema = Schema(MetricsModelTypes.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let actor = MetricsStoreActor(modelContainer: container)
        return PersistentMetricsStorage(
            metricsActor: actor,
            modelContainer: container,
            batchSize: 100_000,  // never auto-flush during test
            flushInterval: 3600,
            bufferCapacity: bufferCapacity
        )
    }

    // MARK: - droppedSinceLaunch > 0 after overflow

    @Test("droppedSinceLaunch is non-zero after flooding past bufferCapacity")
    func droppedSinceLaunchNonZeroAfterFlood() async throws {
        let cap = 10
        let storage = try makeStorage(bufferCapacity: cap)

        // Append 2× capacity
        for i in 0..<(cap * 2) {
            storage.record(MetricEntry(label: "flood", dimensions: [], type: .counter, value: Double(i)))
        }
        await storage._testWaitForPendingAppends()

        let dropped = await storage.droppedSinceLaunch
        #expect(dropped > 0, "Expected some drops after flooding \(cap * 2) entries into capacity \(cap)")
        #expect(dropped == UInt64(cap), "Expected exactly \(cap) drops, got \(dropped)")
    }

    // MARK: - Oldest entries are dropped

    @Test("After overflow the buffer retains exactly bufferCapacity entries")
    func newestSurviveOldestDropped() async throws {
        let cap = 5
        let storage = try makeStorage(bufferCapacity: cap)

        // Append 10 entries: values 0…9
        for i in 0..<10 {
            storage.record(MetricEntry(label: "newest", dimensions: [], type: .counter, value: Double(i)))
        }
        await storage._testWaitForPendingAppends()

        // Verify drop count is exactly total - cap
        let dropped = await storage.droppedSinceLaunch
        #expect(dropped == 5, "Expected exactly 5 drops (10 appended - cap 5)")

        await storage.flushNow()

        // After overflow, exactly cap entries survive (not more, not less)
        let results = storage.query(MetricsQuery(label: "newest"))
        #expect(results.count == cap, "Expected \(cap) entries to survive after overflow")

        // All surviving values must be from the original range 0…9
        let values = results.map(\.value)
        for v in values {
            #expect(v >= 0 && v <= 9, "Unexpected value \(v) — must be in range 0…9")
        }
        // All values must be distinct (no duplicates from the ring)
        #expect(Set(values).count == cap, "Expected \(cap) distinct values after overflow")
    }

    // MARK: - Exact drop count

    @Test("droppedSinceLaunch equals (total appended - bufferCapacity)")
    func exactDropCount() async throws {
        let cap = 7
        let total = 20
        let storage = try makeStorage(bufferCapacity: cap)

        for i in 0..<total {
            storage.record(MetricEntry(label: "exact", dimensions: [], type: .counter, value: Double(i)))
        }
        await storage._testWaitForPendingAppends()

        let dropped = await storage.droppedSinceLaunch
        let expected = UInt64(total - cap)
        #expect(dropped == expected, "Expected \(expected) drops for \(total) appends into cap \(cap), got \(dropped)")
    }

    // MARK: - No drops when within capacity

    @Test("droppedSinceLaunch stays zero when appends stay within capacity")
    func noDropsWithinCapacity() async throws {
        let cap = 50
        let storage = try makeStorage(bufferCapacity: cap)

        for i in 0..<cap {
            storage.record(MetricEntry(label: "nodrop", dimensions: [], type: .counter, value: Double(i)))
        }
        await storage._testWaitForPendingAppends()

        let dropped = await storage.droppedSinceLaunch
        #expect(dropped == 0)
    }

    // MARK: - droppedSinceLaunch persists across flushes

    @Test("droppedSinceLaunch accumulates across multiple overflow+flush cycles")
    func droppedCountPersistsAcrossFlushes() async throws {
        let cap = 3
        let storage = try makeStorage(bufferCapacity: cap)

        // Cycle 1: overflow by 2
        for i in 0..<5 {
            storage.record(MetricEntry(label: "multi", dimensions: [], type: .counter, value: Double(i)))
        }
        await storage._testWaitForPendingAppends()
        await storage.flushNow()

        let droppedAfterCycle1 = await storage.droppedSinceLaunch
        #expect(droppedAfterCycle1 == 2)

        // Cycle 2: overflow by 3 more
        for i in 10..<16 {
            storage.record(MetricEntry(label: "multi", dimensions: [], type: .counter, value: Double(i)))
        }
        await storage._testWaitForPendingAppends()

        let droppedAfterCycle2 = await storage.droppedSinceLaunch
        #expect(droppedAfterCycle2 == 5, "Expected cumulative 5 drops, got \(droppedAfterCycle2)")
    }
}
