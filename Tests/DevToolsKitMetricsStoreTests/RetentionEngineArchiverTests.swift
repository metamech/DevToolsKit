import Foundation
import SwiftData
import Testing

@testable import DevToolsKitMetrics
@testable import DevToolsKitMetricsStore

// MARK: - Stub Archiver for Testing

/// Sendable record of a single archive call (extracts copyable metadata only).
struct ArchiveCall: Sendable {
    let observationCount: Int
    let reason: RetentionPruneReason
}

/// Thread-safe stub archiver that records all archive calls.
/// Uses a dispatch queue for thread-safe access in async context.
final class StubArchiver: Sendable, RetentionArchiver {
    private let queue = DispatchQueue(label: "test.stubarchiver")
    nonisolated(unsafe) private var _calls: [ArchiveCall] = []
    nonisolated(unsafe) private var _shouldThrow: Bool = false

    func archive(observations: [MetricObservation], reason: RetentionPruneReason) async throws {
        // Use dispatch queue's sync method to safely access shared state from async context
        try queue.sync {
            if _shouldThrow {
                throw TestError.archiveFailure
            }
            // Store only the count and reason (observations are @Model objects, not Sendable)
            _calls.append(ArchiveCall(observationCount: observations.count, reason: reason))
        }
    }

    func getCallCount() -> Int {
        queue.sync {
            _calls.count
        }
    }

    func getCalls() -> [ArchiveCall] {
        queue.sync {
            _calls
        }
    }

    func setShouldThrow(_ shouldThrow: Bool) {
        queue.sync {
            _shouldThrow = shouldThrow
        }
    }
}

enum TestError: Error {
    case archiveFailure
}

// MARK: - Test Suite

@Suite(.serialized)
@MainActor
struct RetentionEngineArchiverTests {

    private func makeSetup(
        policy: RetentionPolicy = .default
    ) throws -> (
        ModelContainer, PersistentMetricsStorage, RetentionEngine
    ) {
        let schema = Schema(MetricsModelTypes.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let storage = PersistentMetricsStorage(
            modelContainer: container, batchSize: 1000, flushInterval: 60
        )
        let engine = RetentionEngine(modelContainer: container, policy: policy)
        return (container, storage, engine)
    }

    // MARK: Test 1: Nil archiver is a no-op

    @Test("nilArchiverNoOp")
    func nilArchiverNoOp() async throws {
        let policy = RetentionPolicy(
            rawDataTTL: 3600,  // 1 hour
            archiver: nil  // Explicitly nil
        )
        let (container, storage, engine) = try makeSetup(policy: policy)

        // Record old entry (2 hours ago)
        storage.record(
            MetricEntry(
                timestamp: Date().addingTimeInterval(-7200),
                label: "old.data",
                dimensions: [],
                type: .counter,
                value: 1
            ))
        // Record recent entry
        storage.record(
            MetricEntry(
                timestamp: Date().addingTimeInterval(-300),
                label: "recent.data",
                dimensions: [],
                type: .counter,
                value: 2
            ))
        await storage.flushNow()

        let context = container.mainContext
        let beforeCount = (try? context.fetchCount(FetchDescriptor<MetricObservation>())) ?? 0
        #expect(beforeCount == 2)

        // Run maintenance — should delete old entry but not crash with nil archiver
        await engine.runMaintenanceCycle()

        let afterCount = (try? context.fetchCount(FetchDescriptor<MetricObservation>())) ?? 0
        // Only recent entry should remain
        let observations = try context.fetch(FetchDescriptor<MetricObservation>())
        #expect(observations.allSatisfy { $0.label == "recent.data" })
        #expect(afterCount == 1)
    }

    // MARK: Test 2: TTL purge invokes archiver pre-delete

    @Test("ttlPurgeInvokesArchiverPreDelete")
    func ttlPurgeInvokesArchiverPreDelete() async throws {
        let archiver = StubArchiver()
        let policy = RetentionPolicy(
            rawDataTTL: 3600,  // 1 hour
            archiver: archiver
        )
        let (container, storage, engine) = try makeSetup(policy: policy)

        // Insert N old rows (2 hours ago)
        let oldTime = Date().addingTimeInterval(-7200)
        for i in 0..<10 {
            storage.record(
                MetricEntry(
                    timestamp: oldTime.addingTimeInterval(Double(i)),
                    label: "old.ttl.\(i % 3)",
                    dimensions: [],
                    type: .counter,
                    value: Double(i)
                ))
        }
        // Insert recent rows
        for i in 0..<5 {
            storage.record(
                MetricEntry(
                    timestamp: Date().addingTimeInterval(-300 + Double(i)),
                    label: "recent.ttl.\(i)",
                    dimensions: [],
                    type: .counter,
                    value: Double(100 + i)
                ))
        }
        await storage.flushNow()

        let context = container.mainContext
        let beforeCount = (try? context.fetchCount(FetchDescriptor<MetricObservation>())) ?? 0
        #expect(beforeCount == 15)

        // Run maintenance
        await engine.runMaintenanceCycle()

        // Verify archiver was called with correct reason and count
        let calls = archiver.getCalls()
        #expect(!calls.isEmpty, "Archiver should have been called")

        let totalArchivedCount = calls.reduce(0) { $0 + $1.observationCount }
        #expect(totalArchivedCount == 10, "Archiver should receive all 10 old observations")

        // All calls should have .ttl reason
        for call in calls {
            #expect(call.reason == .ttl)
        }

        // Verify deletion happened after archive (hot store should be empty of old entries)
        let remaining = try context.fetch(FetchDescriptor<MetricObservation>())
        #expect(remaining.allSatisfy { $0.label.hasPrefix("recent.ttl") })
    }

    // MARK: Test 3: Size-cap purge invokes archiver with .sizeCap

    @Test("sizeCapPurgeInvokesArchiverWithSizeCap")
    func sizeCapPurgeInvokesArchiverWithSizeCap() async throws {
        let archiver = StubArchiver()
        let policy = RetentionPolicy(
            sizeCeilingBytes: 256 * 1024,  // 256 KB ceiling
            sizeCeilingFloorRatio: 0.9,
            archiver: archiver
        )

        let schema = Schema(MetricsModelTypes.all)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let dbURL = tempDir.appendingPathComponent("metrics.store")
        let configWithURL = ModelConfiguration(schema: schema, url: dbURL)
        let container = try ModelContainer(for: schema, configurations: [configWithURL])
        let engine = RetentionEngine(modelContainer: container, policy: policy)

        // Insert enough rows to exceed size ceiling (~1500 rows)
        let context = container.mainContext
        for i in 0..<1500 {
            let obs = MetricObservation(
                timestamp: Date().addingTimeInterval(-Double(i)),
                label: "sizecap.metric.\(i % 20)",
                typeRawValue: "counter",
                value: Double(i),
                dimensionsKey: ""
            )
            context.insert(obs)
        }
        try context.save()

        let beforeCount = (try? context.fetchCount(FetchDescriptor<MetricObservation>())) ?? 0
        #expect(beforeCount == 1500)

        // Trigger size-cap enforcement
        let triggered = try await engine.enforceSizeCeiling()
        #expect(triggered == true, "Size ceiling should have been exceeded")

        // Verify archiver was called with .sizeCap reason
        let calls = archiver.getCalls()
        #expect(!calls.isEmpty, "Archiver should have been called during size-cap enforcement")

        // All calls should have .sizeCap reason
        for call in calls {
            #expect(call.reason == .sizeCap)
        }

        // Verify deletion happened (row count should drop)
        let afterCount = (try? context.fetchCount(FetchDescriptor<MetricObservation>())) ?? 0
        #expect(afterCount < beforeCount, "Rows should be deleted during size-cap enforcement")
    }

    // MARK: Test 4: Archiver errors are swallowed

    @Test("archiverErrorsAreSwallowed")
    func archiverErrorsAreSwallowed() async throws {
        let archiver = StubArchiver()
        archiver.setShouldThrow(true)  // Will throw on every call

        let policy = RetentionPolicy(
            rawDataTTL: 3600,
            archiver: archiver
        )
        let (container, storage, engine) = try makeSetup(policy: policy)

        // Insert old and recent entries
        let oldTime = Date().addingTimeInterval(-7200)
        for i in 0..<5 {
            storage.record(
                MetricEntry(
                    timestamp: oldTime.addingTimeInterval(Double(i)),
                    label: "error.test",
                    dimensions: [],
                    type: .counter,
                    value: Double(i)
                ))
        }
        for i in 0..<3 {
            storage.record(
                MetricEntry(
                    timestamp: Date().addingTimeInterval(-300 + Double(i)),
                    label: "safe.data",
                    dimensions: [],
                    type: .counter,
                    value: Double(i)
                ))
        }
        await storage.flushNow()

        let context = container.mainContext
        let beforeCount = (try? context.fetchCount(FetchDescriptor<MetricObservation>())) ?? 0
        #expect(beforeCount == 8)

        // Run maintenance — should NOT throw despite archiver failures
        await engine.runMaintenanceCycle()

        // Deletion should still happen despite archiver throwing
        let remaining = try context.fetch(FetchDescriptor<MetricObservation>())
        #expect(remaining.allSatisfy { $0.label == "safe.data" })
    }

    // MARK: Test 5: TTL batch size

    @Test("ttlBatchSizeRespected")
    func ttlBatchSizeRespected() async throws {
        let archiver = StubArchiver()
        // Set rollup TTLs far in the future so createRollups() short-circuits (no completed buckets).
        // This isolates the test to TTL purge time, not rollup creation time.
        let policy = RetentionPolicy(
            rawDataTTL: 3600,
            hourlyRollupTTL: 1_000_000_000,  // ~31 years in future
            dailyRollupTTL: 1_000_000_000,   // ~31 years in future
            archiver: archiver
        )
        let (container, _, engine) = try makeSetup(policy: policy)

        // Insert 18,000 old rows directly via ModelContext (bypass PersistentMetricsStorage.record()
        // which cycles through 18+ batch auto-flushes on MainActor).
        // This matches the fast insertion pattern already proven in sizeCapPurgeInvokesArchiverWithSizeCap.
        let context = container.mainContext
        let oldTime = Date().addingTimeInterval(-7200)
        for i in 0..<18_000 {
            let obs = MetricObservation(
                timestamp: oldTime.addingTimeInterval(Double(i % 3600)),
                label: "batch.test",
                typeRawValue: "counter",
                value: Double(i),
                dimensionsKey: ""
            )
            context.insert(obs)
        }
        // Add some recent entries to survive the purge
        for i in 0..<100 {
            let obs = MetricObservation(
                timestamp: Date().addingTimeInterval(-300 + Double(i)),
                label: "recent.batch",
                typeRawValue: "counter",
                value: Double(i),
                dimensionsKey: ""
            )
            context.insert(obs)
        }
        try context.save()

        // Run maintenance — rollup pass will short-circuit since no completed buckets; focus on TTL purge
        await engine.runMaintenanceCycle()

        // Verify archiver was called multiple times with batches ≤ 8,000
        let calls = archiver.getCalls()
        #expect(calls.count >= 3, "Archiver should have been called at least 3 times for 18k rows (8k + 8k + 2k)")

        var totalArchived = 0
        for call in calls {
            #expect(call.observationCount <= 8_000, "Batch size should not exceed 8,000; got \(call.observationCount)")
            #expect(call.reason == .ttl)
            totalArchived += call.observationCount
        }
        #expect(totalArchived == 18_000, "Total archived should equal 18,000; got \(totalArchived)")
    }

    // MARK: Test 6: Wall-time budget for 50k-row TTL purge
    //
    // Performance benchmark (gated by DTK_PERF_TESTS environment variable).
    // This test is intentionally slow and should only run in nightly CI or by explicit opt-in.
    // It validates that the archiver hook does not degrade purge performance on large datasets.

    @Test("wallTimeBudgetFor50kRowTTLPurge")
    func wallTimeBudgetFor50kRowTTLPurge() async throws {
        // Skip this test in normal unit-test runs; only run when explicitly opted in via env var.
        guard ProcessInfo.processInfo.environment["DTK_PERF_TESTS"] != nil else {
            return  // Test skipped
        }

        let archiver = StubArchiver()  // No-op archiver
        // Set rollup TTLs far in the future so createRollups() short-circuits.
        // This isolates the performance budget to the TTL purge, not rollup creation.
        let policy = RetentionPolicy(
            rawDataTTL: 3600,
            hourlyRollupTTL: 1_000_000_000,  // ~31 years in future
            dailyRollupTTL: 1_000_000_000,   // ~31 years in future
            archiver: archiver
        )
        let (_, storage, engine) = try makeSetup(policy: policy)

        // Insert 50,000 old rows
        let oldTime = Date().addingTimeInterval(-7200)
        for i in 0..<50_000 {
            storage.record(
                MetricEntry(
                    timestamp: oldTime.addingTimeInterval(Double(i % 3600)),
                    label: "perf.test",
                    dimensions: [],
                    type: .counter,
                    value: Double(i % 1000)
                ))
        }
        await storage.flushNow()

        let startTime = Date()
        await engine.runMaintenanceCycle()
        let elapsed = Date().timeIntervalSince(startTime)

        // Assert wall time < 30 seconds (generous budget for nightly/manual perf runs).
        // This budget measures purge + archiver overhead, not rollup creation (which is short-circuited).
        #expect(elapsed < 30, "50k-row TTL purge should complete in <30s; took \(String(format: "%.2f", elapsed))s")
    }
}
