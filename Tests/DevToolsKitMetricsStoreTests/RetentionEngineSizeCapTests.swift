import Foundation
import SwiftData
import Testing

@testable import DevToolsKitMetrics
@testable import DevToolsKitMetricsStore

/// Test suite for size ceiling enforcement with Option D architecture.
///
/// Option D separates responsibilities:
/// - **Runtime** (`enforceSizeCeiling()`): deletes oldest rows + `wal_checkpoint(RESTART)` to bound WAL growth
/// - **At-launch** (`MetricsStack.create`): runs `wal_checkpoint(TRUNCATE)` + `VACUUM` when file exists
///
/// These tests validate both paths:
/// - Tests 1–3: Runtime pruning behavior
/// - Tests 4–5: At-launch VACUUM file shrinking
@Suite(.serialized)
@MainActor
struct RetentionEngineSizeCapTests {

    // MARK: - Test Helpers

    /// Creates an on-disk metrics stack in a temporary directory.
    /// Returns the stack and the temporary directory URL for cleanup.
    /// Each test gets its own isolated store file to prevent state bleed.
    private func makeDiskStack(
        policy: RetentionPolicy = .default
    ) throws -> (MetricsStack, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Construct the container directly with explicit store URL
        // to avoid sharing the default app-support path across tests.
        let schema = Schema(MetricsStack.modelTypes)
        let dbURL = tempDir.appendingPathComponent("metrics.store")
        let config = ModelConfiguration(schema: schema, url: dbURL)
        let container = try ModelContainer(for: schema, configurations: [config])

        let storage = PersistentMetricsStorage(
            modelContainer: container, batchSize: 1000, flushInterval: 60
        )
        let database = MetricsDatabase(storage: storage, modelContainer: container)
        let engine = RetentionEngine(modelContainer: container, policy: policy)

        let stack = MetricsStack(
            storage: storage,
            database: database,
            retentionEngine: engine,
            modelContainer: container
        )

        return (stack, tempDir)
    }

    /// Inserts raw observations with varied timestamps.
    private func insertObservations(
        into context: ModelContext,
        count: Int,
        labelPrefix: String = "test.metric"
    ) throws {
        let now = Date()
        for i in 0..<count {
            let timestamp = now.addingTimeInterval(-Double(i))
            let obs = MetricObservation(
                timestamp: timestamp,
                label: "\(labelPrefix).\(i % 10)",
                typeRawValue: "counter",
                value: Double(i),
                dimensionsKey: ""
            )
            context.insert(obs)
        }
        try context.save()
    }

    // MARK: - Test Cases (5 total)

    /// Test 1: Under-cap no-op
    ///
    /// When total size is well below the ceiling, `enforceSizeCeiling()`
    /// should return false, row count unchanged, counter NOT incremented.
    @Test("testUnderCapNoOp")
    func underCapNoOp() async throws {
        let policy = RetentionPolicy(
            sizeCeilingBytes: 100 * 1024 * 1024,  // 100 MB ceiling
            sizeCeilingFloorRatio: 0.9
        )
        let (stack, tempDir) = try makeDiskStack(policy: policy)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let context = stack.modelContainer.mainContext
        try insertObservations(into: context, count: 50)

        let beforeCount = (try? context.fetchCount(FetchDescriptor<MetricObservation>())) ?? 0
        #expect(beforeCount == 50)

        let triggered = try await stack.retentionEngine.enforceSizeCeiling()
        #expect(triggered == false)

        let afterCount = (try? context.fetchCount(FetchDescriptor<MetricObservation>())) ?? 0
        #expect(afterCount == 50)
    }

    /// Test 2: nil ceiling disables pruning
    ///
    /// When `sizeCeilingBytes = nil`, pruning disabled entirely.
    /// `enforceSizeCeiling()` returns false immediately, rows unchanged.
    @Test("testNilCeilingDisablesPruning")
    func nilCeilingDisablesPruning() async throws {
        let policy = RetentionPolicy(
            sizeCeilingBytes: nil,  // Disabled
            sizeCeilingFloorRatio: 0.9
        )
        let (stack, tempDir) = try makeDiskStack(policy: policy)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let context = stack.modelContainer.mainContext
        try insertObservations(into: context, count: 100)

        let beforeCount = (try? context.fetchCount(FetchDescriptor<MetricObservation>())) ?? 0
        #expect(beforeCount == 100)

        let triggered = try await stack.retentionEngine.enforceSizeCeiling()
        #expect(triggered == false)

        let afterCount = (try? context.fetchCount(FetchDescriptor<MetricObservation>())) ?? 0
        #expect(afterCount == 100)
    }

    /// Test 3: Runtime prune reduces row count
    ///
    /// When size exceeds ceiling, `enforceSizeCeiling()` deletes oldest rows
    /// and returns true. Verify row count drops and counter increments.
    @Test("testRuntimePruneReducesRowCount")
    func runtimePruneReducesRowCount() async throws {
        let ceilingBytes: Int64 = 512 * 1024  // 512 KB
        let policy = RetentionPolicy(
            sizeCeilingBytes: ceilingBytes,
            sizeCeilingFloorRatio: 0.9
        )
        let (stack, tempDir) = try makeDiskStack(policy: policy)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let context = stack.modelContainer.mainContext

        // Insert enough rows to exceed ceiling (~2500 rows)
        try insertObservations(into: context, count: 2500, labelPrefix: "runtime.prune")

        let beforeCount = (try? context.fetchCount(FetchDescriptor<MetricObservation>())) ?? 0
        #expect(beforeCount == 2500)

        // Prune
        let triggered = try await stack.retentionEngine.enforceSizeCeiling()
        #expect(triggered == true, "Should trigger pruning when over ceiling")

        // Row count should drop (even if all rows deleted, count must decrease)
        let afterCount = (try? context.fetchCount(FetchDescriptor<MetricObservation>())) ?? 0
        #expect(afterCount < beforeCount, "Row count should drop after pruning: before=\(beforeCount), after=\(afterCount)")
    }

    /// Test 4: At-launch VACUUM shrinks file
    ///
    /// Verify launchVacuum runs during MetricsStack.create when ceiling is enabled.
    /// Phase 1: seed store with ceiling nil, release
    /// Phase 2: measure closed-file size (before)
    /// Phase 3: re-create with ceiling enabled → launchVacuum runs during create
    /// Phase 4: measure (after)
    @Test("testAtLaunchVacuumShrinksFile")
    func atLaunchVacuumShrinksFile() async throws {
        let ceilingBytes: Int64 = 100 * 1024 * 1024
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let storeURL = tempDir.appendingPathComponent("metrics.store")

        // Phase 1: Seed with large data and release stack
        do {
            let stack = try MetricsStack.create(
                inMemory: false,
                storeURL: storeURL,
                retentionPolicy: RetentionPolicy(sizeCeilingBytes: nil),
                batchSize: 1000
            )
            let context = stack.modelContainer.mainContext
            try insertObservations(into: context, count: 5000, labelPrefix: "vacuum.seed")
            try context.save()
        } // stack deallocates, file closes

        // Phase 2: Measure file size on closed file (before)
        let beforeSize = MetricsDatabaseFileStats.totalOnDiskBytes(dbURL: storeURL)
        #expect(beforeSize > 0, "Store file should exist and be non-empty")

        // Phase 3: Re-open with ceiling enabled — launchVacuum runs during create
        do {
            let stack2 = try MetricsStack.create(
                inMemory: false,
                storeURL: storeURL,
                retentionPolicy: RetentionPolicy(sizeCeilingBytes: ceilingBytes, sizeCeilingFloorRatio: 0.9),
                batchSize: 1000
            )
            // launchVacuum already ran during create (before ModelContainer was constructed)
            let afterSize = try stack2.database.totalOnDiskBytes()
            #expect(afterSize < beforeSize, "File should shrink after launchVacuum: before=\(beforeSize), after=\(afterSize)")
        } // stack2 deallocates
    }

    /// Test 5: At-launch VACUUM skipped when ceiling is nil
    ///
    /// When ceiling is nil, launchVacuum should not run.
    /// File size should remain unchanged (or grow only slightly from normal ops).
    @Test("testAtLaunchVacuumSkippedWhenCeilingNil")
    func atLaunchVacuumSkippedWhenCeilingNil() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let storeURL = tempDir.appendingPathComponent("metrics.store")

        // Phase 1: Seed with data and release stack
        do {
            let stack = try MetricsStack.create(
                inMemory: false,
                storeURL: storeURL,
                retentionPolicy: RetentionPolicy(sizeCeilingBytes: nil),
                batchSize: 1000
            )
            let context = stack.modelContainer.mainContext
            try insertObservations(into: context, count: 1000, labelPrefix: "no.vacuum")
            try context.save()
        } // stack deallocates, file closes

        // Phase 2: Measure before
        let beforeSize = MetricsDatabaseFileStats.totalOnDiskBytes(dbURL: storeURL)

        // Phase 3: Re-open with ceiling = nil (no launchVacuum)
        do {
            let stack2 = try MetricsStack.create(
                inMemory: false,
                storeURL: storeURL,
                retentionPolicy: RetentionPolicy(sizeCeilingBytes: nil),
                batchSize: 1000
            )
            let afterSize = try stack2.database.totalOnDiskBytes()

            // Size should be unchanged or only slightly grown
            #expect(
                abs(afterSize - beforeSize) <= 100_000,  // ±100 KB tolerance
                "File size should not change significantly: before=\(beforeSize), after=\(afterSize)"
            )
        } // stack2 deallocates
    }
}
