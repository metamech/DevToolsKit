import Foundation
import SwiftData
import Testing

@testable import DevToolsKitMetrics
@testable import DevToolsKitMetricsStore

/// Regression tests for #1429 crash fix.
///
/// The original crash occurred when:
/// 1. A query (via `execute()`) fetched `MetricObservation` instances
/// 2. The query code mapped dimensions: `obs.dimensions.map { ($0.key, $0.value) }`
/// 3. Concurrently, a retention sweep deleted rows via `enforceSizeCeiling` / `deleteToFloor`
/// 4. The concurrent delete triggered a data race: SwiftData `_PersistedProperty` assertion failed
///    on `MetricDimension.key.getter` because one context was deleting while another was reading.
///
/// The fix introduces `MetricsStoreActor` (@ModelActor), which owns the sole `ModelContext`
/// for the metrics store. All reads (queries) and maintenance writes (deletions) are serialized
/// on the actor, eliminating the data race.
///
/// These tests stress the concurrent-safe code path by:
/// - Inserting a large dataset (2000+ observations with dimensions)
/// - Running parallel query reads and retention deletes
/// - Verifying no crash, no assertion failure, and final state consistency
@Suite(.serialized)
struct MetricsStoreActorConcurrencyTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(MetricsModelTypes.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeActor(container: ModelContainer) async -> MetricsStoreActor {
        return MetricsStoreActor(modelContainer: container)
    }

    // MARK: - Query + Delete Concurrency

    /// Test: Concurrent queries and size-ceiling enforcement don't crash.
    ///
    /// Seeds 2000 observations with dimensions, then runs a tight loop of:
    /// - Task 1: 100 iterations of execute(query) that map dimensions
    /// - Task 2: 50 iterations of enforceSizeCeiling with small batches
    /// Verifies no throw, no crash, and observation count monotonic.
    @Test("concurrent queries and deletions don't crash")
    func concurrentQueriesAndDeletions() async throws {
        let container = try makeContainer()
        let actor = await makeActor(container: container)

        let now = Date()
        var dtos: [MetricObservationDTO] = []

        for i in 0..<2000 {
            let dims = [
                (String(format: "region_%d", i % 10), "us"),
                (String(format: "env_%d", i % 5), "prod"),
                ("service", "metrics-store"),
            ]
            let entry = MetricEntry(
                timestamp: now.addingTimeInterval(Double(i)),
                label: "request.duration",
                dimensions: dims,
                type: .timer,
                value: Double(i % 100)
            )
            dtos.append(MetricObservationDTO(entry: entry))
        }

        try await actor.insert(dtos)
        let initialCount = try await actor.observationCount()
        #expect(initialCount == 2000)

        var finalCount: Int = 0

        let crashes = try await withThrowingTaskGroup(of: [Error].self) { group in
            group.addTask {
                var localErrors: [Error] = []
                for _ in 0..<100 {
                    do {
                        _ = try await actor.execute(DatabaseQuery())
                    } catch {
                        localErrors.append(error)
                    }
                }
                return localErrors
            }

            group.addTask {
                var localErrors: [Error] = []
                for _ in 0..<50 {
                    do {
                        let policy = RetentionPolicy(sizeCeilingBytes: 0)
                        _ = try await actor.enforceSizeCeiling(
                            policy: policy,
                            dbURL: nil
                        )
                    } catch {
                        localErrors.append(error)
                    }
                }
                return localErrors
            }

            return try await group.reduce(into: []) { $0 += $1 }
        }

        finalCount = try await actor.observationCount()

        #expect(crashes.isEmpty, "No crashes during concurrent queries and deletions")
        #expect(finalCount <= initialCount, "Observation count monotonic (only decreases)")
    }

    /// Test: Dimension mapping during concurrent deletion (exact crash path).
    ///
    /// Replicates the exact crash scenario:
    /// 1. Insert observations with dimensions
    /// 2. Run query that maps dimensions.map { ($0.key, $0.value) }
    /// 3. Concurrently call enforceSizeCeiling which deletes observations
    /// 4. Verify no SwiftData assertion on dimension.key access
    @Test("dimension mapping survives concurrent deletion")
    func dimensionMappingSurvivesConcurrentDeletion() async throws {
        let container = try makeContainer()
        let actor = await makeActor(container: container)

        let now = Date()
        var dtos: [MetricObservationDTO] = []

        for i in 0..<500 {
            let dims = [
                ("env", "prod"),
                ("region", "us-west-2"),
                ("service", "api"),
            ]
            let entry = MetricEntry(
                timestamp: now.addingTimeInterval(Double(i)),
                label: "http.requests.total",
                dimensions: dims,
                type: .counter,
                value: Double(i)
            )
            dtos.append(MetricObservationDTO(entry: entry))
        }

        try await actor.insert(dtos)

        let dimensionAccessErrors = try await withThrowingTaskGroup(of: [Error].self) { group in
            group.addTask {
                var localErrors: [Error] = []
                for _ in 0..<50 {
                    do {
                        let rawObs = try await actor.testFetchRawObservationsWithDimensions()
                        _ = rawObs.map { (_, dims) in dims.map { ($0.0, $0.1) } }
                    } catch {
                        localErrors.append(error)
                    }
                }
                return localErrors
            }

            group.addTask {
                var localErrors: [Error] = []
                for _ in 0..<20 {
                    do {
                        let policy = RetentionPolicy(sizeCeilingBytes: 0)
                        _ = try await actor.enforceSizeCeiling(
                            policy: policy,
                            dbURL: nil
                        )
                    } catch {
                        localErrors.append(error)
                    }
                }
                return localErrors
            }

            return try await group.reduce(into: []) { $0 += $1 }
        }

        #expect(
            dimensionAccessErrors.isEmpty,
            "No errors mapping dimensions during concurrent deletion"
        )
    }

    /// Test: Query execution during TTL purge (maintenance path).
    ///
    /// Runs a full maintenance cycle (which purges TTL observations) while
    /// concurrently executing queries. Verifies both operations complete safely.
    @Test("queries survive concurrent maintenance cycle")
    func queriesSurviveConcurrentMaintenanceCycle() async throws {
        let container = try makeContainer()
        let actor = await makeActor(container: container)

        let now = Date()
        let oldTime = now.addingTimeInterval(-86_400 * 10)
        var dtos: [MetricObservationDTO] = []

        for i in 0..<1000 {
            let timestamp = i % 2 == 0 ? oldTime : now
            let dims = [("type", i % 2 == 0 ? "old" : "new")]
            let entry = MetricEntry(
                timestamp: timestamp,
                label: "test.metric",
                dimensions: dims,
                type: .counter,
                value: Double(i)
            )
            dtos.append(MetricObservationDTO(entry: entry))
        }

        try await actor.insert(dtos)
        let preMaintenanceCount = try await actor.observationCount()

        let errors = try await withThrowingTaskGroup(of: [Error].self) { group in
            group.addTask {
                var localErrors: [Error] = []
                do {
                    let policy = RetentionPolicy.default
                    try await actor.runMaintenanceCycle(policy: policy, dbURL: nil)
                } catch {
                    localErrors.append(error)
                }
                return localErrors
            }

            group.addTask {
                var localErrors: [Error] = []
                for _ in 0..<30 {
                    do {
                        _ = try await actor.execute(DatabaseQuery())
                    } catch {
                        localErrors.append(error)
                    }
                }
                return localErrors
            }

            return try await group.reduce(into: []) { $0 += $1 }
        }

        let postMaintenanceCount = try await actor.observationCount()

        #expect(errors.isEmpty, "No errors during maintenance + query concurrency")
        #expect(
            postMaintenanceCount <= preMaintenanceCount,
            "Observation count monotonic after maintenance"
        )
    }

    /// Test: High-concurrency stress with multiple query/delete patterns.
    ///
    /// Spawns 4 concurrent tasks: 2 query loops, 2 delete loops with varying sizes.
    /// Each task runs 50+ iterations. Verifies final state consistency.
    @Test("high-concurrency stress test")
    func highConcurrencyStress() async throws {
        let container = try makeContainer()
        let actor = await makeActor(container: container)

        let now = Date()
        var dtos: [MetricObservationDTO] = []

        for i in 0..<1500 {
            let dims = [("batch", String(i / 300))]
            let entry = MetricEntry(
                timestamp: now.addingTimeInterval(Double(i)),
                label: "stress.test",
                dimensions: dims,
                type: .counter,
                value: Double(i)
            )
            dtos.append(MetricObservationDTO(entry: entry))
        }

        try await actor.insert(dtos)
        let preCount = try await actor.observationCount()

        let errors = try await withThrowingTaskGroup(of: [Error].self) { group in
            for taskIdx in 0..<4 {
                group.addTask {
                    var localErrors: [Error] = []
                    if taskIdx % 2 == 0 {
                        for _ in 0..<50 {
                            do {
                                _ = try await actor.execute(DatabaseQuery())
                            } catch {
                                localErrors.append(error)
                            }
                        }
                    } else {
                        for batchIdx in 0..<50 {
                            do {
                                let batchSize = batchIdx % 3 == 0 ? 10 : 50
                                _ = try await actor.deleteOldestRawObservations(batchSize: batchSize)
                            } catch {
                                localErrors.append(error)
                            }
                        }
                    }
                    return localErrors
                }
            }

            return try await group.reduce(into: []) { $0 += $1 }
        }

        let postCount = try await actor.observationCount()

        #expect(errors.isEmpty, "No errors in high-concurrency stress test")
        #expect(postCount <= preCount, "Observation count remains monotonic")
    }

    // MARK: - ClaudeSessionDetailViewModel Query Shape

    /// Test: Exact ClaudeSessionDetailViewModel.metricsFromDatabase query shape
    /// runs concurrently with retention deletion.
    ///
    /// The original crash occurred in this specific code path:
    /// ```swift
    /// let rawObs = try await metricsActor.testFetchRawObservationsWithDimensions()
    /// return rawObs.map { (label, dimensions) in
    ///     (label, dimensions.map { ($0.0, $0.1) })
    /// }
    /// ```
    ///
    /// This test replicates that exact mapping while retention deletes rows.
    /// The actor serializes both the raw fetch and the concurrent deletes,
    /// preventing the data race that caused SwiftData assertion in #1429.
    @Test("ClaudeSessionDetailViewModel query shape is safe under concurrent deletion")
    func claudeSessionDetailViewModelQuerySafe() async throws {
        let container = try makeContainer()
        let actor = await makeActor(container: container)

        let now = Date()
        var dtos: [MetricObservationDTO] = []

        for i in 0..<800 {
            let dims = [
                ("session", String(i / 100)),
                ("type", i % 2 == 0 ? "token" : "latency"),
            ]
            let label = i % 3 == 0 ? "claude.tokens" : "claude.latency"
            let entry = MetricEntry(
                timestamp: now.addingTimeInterval(Double(i)),
                label: label,
                dimensions: dims,
                type: i % 3 == 0 ? .counter : .timer,
                value: Double(i % 1000)
            )
            dtos.append(MetricObservationDTO(entry: entry))
        }

        try await actor.insert(dtos)

        let mappingErrors = try await withThrowingTaskGroup(of: [Error].self) { group in
            group.addTask {
                var localErrors: [Error] = []
                for _ in 0..<40 {
                    do {
                        let rawObs = try await actor.testFetchRawObservationsWithDimensions()
                        _ = rawObs.map { (label, dimensions) in
                            (label, dimensions.map { ($0.0, $0.1) })
                        }
                    } catch {
                        localErrors.append(error)
                    }
                }
                return localErrors
            }

            group.addTask {
                var localErrors: [Error] = []
                for _ in 0..<30 {
                    do {
                        let policy = RetentionPolicy(sizeCeilingBytes: 0)
                        _ = try await actor.enforceSizeCeiling(policy: policy, dbURL: nil)
                    } catch {
                        localErrors.append(error)
                    }
                }
                return localErrors
            }

            return try await group.reduce(into: []) { $0 += $1 }
        }

        #expect(
            mappingErrors.isEmpty,
            "ClaudeSessionDetailViewModel query shape safe during concurrent deletion"
        )
    }

    /// Test: Verify actor serialization prevents data race on dimension keys.
    ///
    /// Stress-tests accessing dimension.key while concurrent deletes occur.
    /// If the actor didn't serialize access, this would trigger the original
    /// SwiftData _PersistedProperty assertion failure.
    @Test("dimension.key access serialized via actor")
    func dimensionKeyAccessSerialized() async throws {
        let container = try makeContainer()
        let actor = await makeActor(container: container)

        let now = Date()
        let keyCounts = (0..<20).map { String(format: "key_%02d", $0) }
        var dtos: [MetricObservationDTO] = []

        for i in 0..<1200 {
            let keyIdx = i % keyCounts.count
            let dims = [(keyCounts[keyIdx], "value")]
            let entry = MetricEntry(
                timestamp: now.addingTimeInterval(Double(i)),
                label: "key.test",
                dimensions: dims,
                type: .counter,
                value: Double(i)
            )
            dtos.append(MetricObservationDTO(entry: entry))
        }

        try await actor.insert(dtos)

        let (readErrors, keysAccessed) = try await withThrowingTaskGroup(
            of: (errors: [Error], keys: [String]).self
        ) { group in
            group.addTask {
                var localErrors: [Error] = []
                var localKeys: [String] = []
                for _ in 0..<60 {
                    do {
                        let rawObs = try await actor.testFetchRawObservationsWithDimensions()
                        for (_, dims) in rawObs {
                            let keys = dims.map { $0.0 }
                            localKeys.append(contentsOf: keys)
                        }
                    } catch {
                        localErrors.append(error)
                    }
                }
                return (errors: localErrors, keys: localKeys)
            }

            group.addTask {
                var localErrors: [Error] = []
                for _ in 0..<25 {
                    do {
                        _ = try await actor.deleteOldestRawObservations(batchSize: 50)
                    } catch {
                        localErrors.append(error)
                    }
                }
                return (errors: localErrors, keys: [])
            }

            return try await group.reduce(into: (errors: [], keys: [])) {
                $0.errors += $1.errors
                $0.keys += $1.keys
            }
        }

        #expect(readErrors.isEmpty, "No errors accessing dimension keys during deletion")
        #expect(!keysAccessed.isEmpty, "Keys were successfully accessed")
    }
}
