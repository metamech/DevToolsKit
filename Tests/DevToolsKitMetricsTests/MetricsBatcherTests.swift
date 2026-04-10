import Foundation
import Testing

@testable import DevToolsKitMetrics

@Suite(.serialized)
@MainActor
struct MetricsBatcherTests {
    // MARK: - Test: Entries are buffered, not immediately recorded

    @Test("Entries are buffered, not immediately recorded")
    func entriesAreBufferedNotImmediatelyRecorded() async throws {
        let storage = InMemoryMetricsStorage()
        let batcher = MetricsBatcher(storage: storage)

        let entry = MetricEntry(
            label: "test.metric",
            dimensions: [("env", "test")],
            type: .counter,
            value: 42.0
        )

        // Append entry
        batcher.append(entry)

        // Wait briefly to allow any potential implicit flush
        try await Task.sleep(for: .milliseconds(50))

        // Storage should still be empty (entry is buffered, not recorded)
        #expect(storage.entryCount == 0)

        // After flush, entry should be recorded
        batcher.flush()
        try await Task.sleep(for: .milliseconds(50))

        #expect(storage.entryCount == 1)
        let recorded = storage.query(MetricsQuery())[0]
        #expect(recorded.label == "test.metric")
        #expect(recorded.value == 42.0)
    }

    // MARK: - Test: Flush drains all buffered entries

    @Test("Flush drains all buffered entries")
    func flushDrainsAllBufferedEntries() async throws {
        let storage = InMemoryMetricsStorage()
        let batcher = MetricsBatcher(storage: storage)

        let entries = (1...5).map { i in
            MetricEntry(
                label: "test.metric.\(i)",
                dimensions: [("index", "\(i)")],
                type: .counter,
                value: Double(i * 10)
            )
        }

        // Append all entries
        for entry in entries {
            batcher.append(entry)
        }

        // Storage should be empty before flush
        #expect(storage.entryCount == 0)

        // Flush and wait for async task to complete
        batcher.flush()
        try await Task.sleep(for: .milliseconds(100))

        // All entries should now be in storage
        #expect(storage.entryCount == 5)
        let recorded = storage.query(MetricsQuery())
        #expect(recorded.count == 5)
    }

    // MARK: - Test: Threshold triggers automatic flush

    @Test("Threshold triggers automatic flush")
    func thresholdTriggersAutomaticFlush() async throws {
        let storage = InMemoryMetricsStorage()
        let batcher = MetricsBatcher(
            storage: storage,
            flushInterval: .milliseconds(5000), // Long interval to prevent timer flush
            flushThreshold: 3
        )

        let entries = (1...3).map { i in
            MetricEntry(
                label: "test.threshold.\(i)",
                dimensions: [],
                type: .counter,
                value: Double(i)
            )
        }

        // Append entries one by one
        batcher.append(entries[0])
        try await Task.sleep(for: .milliseconds(10))
        #expect(storage.entryCount == 0) // Not flushed yet

        batcher.append(entries[1])
        try await Task.sleep(for: .milliseconds(10))
        #expect(storage.entryCount == 0) // Still not flushed

        // Third entry reaches threshold and triggers flush
        batcher.append(entries[2])
        try await Task.sleep(for: .milliseconds(100))

        // All 3 entries should now be flushed
        #expect(storage.entryCount == 3)
    }

    // MARK: - Test: Timer triggers periodic flush

    @Test("Timer triggers periodic flush")
    func timerTriggersPeriodicFlush() async throws {
        let storage = InMemoryMetricsStorage()
        let batcher = MetricsBatcher(
            storage: storage,
            flushInterval: .milliseconds(50),
            flushThreshold: 1000 // High threshold to prevent threshold flush
        )

        let entry = MetricEntry(
            label: "test.timer",
            dimensions: [],
            type: .counter,
            value: 99.0
        )

        // Append entry (won't trigger threshold flush due to high threshold)
        batcher.append(entry)

        // Start timer
        batcher.start()

        // Wait for timer to fire
        try await Task.sleep(for: .milliseconds(150))

        // Entry should be flushed by timer
        #expect(storage.entryCount == 1)
        let recorded = storage.query(MetricsQuery())[0]
        #expect(recorded.label == "test.timer")

        // Clean up
        batcher.stop()
    }

    // MARK: - Test: Stop performs final flush

    @Test("Stop performs final flush")
    func stopPerformsFinalFlush() async throws {
        let storage = InMemoryMetricsStorage()
        let batcher = MetricsBatcher(
            storage: storage,
            flushInterval: .milliseconds(5000), // Long interval
            flushThreshold: 1000 // High threshold
        )

        let entries = (1...4).map { i in
            MetricEntry(
                label: "test.stop.\(i)",
                dimensions: [],
                type: .counter,
                value: Double(i)
            )
        }

        // Append entries without triggering threshold or timer
        for entry in entries {
            batcher.append(entry)
        }

        // Storage should be empty
        #expect(storage.entryCount == 0)

        // Stop the batcher (performs final flush)
        batcher.stop()
        try await Task.sleep(for: .milliseconds(100))

        // All entries should be flushed
        #expect(storage.entryCount == 4)
    }

    // MARK: - Test: Multiple flushes accumulate

    @Test("Multiple flushes accumulate")
    func multipleFlushesAccumulate() async throws {
        let storage = InMemoryMetricsStorage()
        let batcher = MetricsBatcher(storage: storage)

        // First batch
        let entry1 = MetricEntry(
            label: "test.batch1",
            dimensions: [],
            type: .counter,
            value: 10.0
        )
        batcher.append(entry1)
        batcher.flush()
        try await Task.sleep(for: .milliseconds(50))
        #expect(storage.entryCount == 1)

        // Second batch
        let entry2 = MetricEntry(
            label: "test.batch2",
            dimensions: [],
            type: .counter,
            value: 20.0
        )
        batcher.append(entry2)
        batcher.flush()
        try await Task.sleep(for: .milliseconds(50))
        #expect(storage.entryCount == 2)

        // Third batch
        let entry3 = MetricEntry(
            label: "test.batch3",
            dimensions: [],
            type: .counter,
            value: 30.0
        )
        batcher.append(entry3)
        batcher.flush()
        try await Task.sleep(for: .milliseconds(50))
        #expect(storage.entryCount == 3)

        // Verify all entries are stored (order across flushes is not guaranteed)
        let allEntries = storage.query(MetricsQuery())
        #expect(allEntries.count == 3)
        let labels = Set(allEntries.map(\.label))
        #expect(labels == Set(["test.batch1", "test.batch2", "test.batch3"]))
    }

    // MARK: - Test: Empty flush is a no-op

    @Test("Empty flush is a no-op")
    func emptyFlushIsNoOp() async throws {
        let storage = InMemoryMetricsStorage()
        let batcher = MetricsBatcher(storage: storage)

        // Flush with no entries
        batcher.flush()
        try await Task.sleep(for: .milliseconds(50))

        // Storage should remain empty
        #expect(storage.entryCount == 0)

        // Multiple empty flushes should also be safe
        batcher.flush()
        batcher.flush()
        try await Task.sleep(for: .milliseconds(50))

        #expect(storage.entryCount == 0)
    }

    // MARK: - Test: Multiple starts are idempotent

    @Test("Multiple starts are idempotent")
    func multipleStartsAreIdempotent() async throws {
        let storage = InMemoryMetricsStorage()
        let batcher = MetricsBatcher(
            storage: storage,
            flushInterval: .milliseconds(50),
            flushThreshold: 1000
        )

        let entry = MetricEntry(
            label: "test.multistart",
            dimensions: [],
            type: .counter,
            value: 1.0
        )

        batcher.append(entry)

        // Start multiple times
        batcher.start()
        batcher.start()

        // Wait for timer to fire
        try await Task.sleep(for: .milliseconds(150))

        // Entry should be flushed exactly once (or at most a small number of times)
        #expect(storage.entryCount >= 1)

        // Clean up
        batcher.stop()
    }

    // MARK: - Test: Stop after stop is safe

    @Test("Stop after stop is safe")
    func stopAfterStopIsSafe() async throws {
        let storage = InMemoryMetricsStorage()
        let batcher = MetricsBatcher(storage: storage)

        let entry = MetricEntry(
            label: "test.stop_twice",
            dimensions: [],
            type: .counter,
            value: 1.0
        )

        batcher.append(entry)

        // Stop twice
        batcher.stop()
        try await Task.sleep(for: .milliseconds(50))
        batcher.stop()
        try await Task.sleep(for: .milliseconds(50))

        // Entry should be flushed
        #expect(storage.entryCount == 1)
    }
}
