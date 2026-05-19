import Foundation
import SwiftData
import Testing

@testable import DevToolsKitMetrics
@testable import DevToolsKitMetricsStore

/// Tests that verify the `insertBatched` path produces correct `MetricDefinition`
/// counts and that wall-time for 1 000 entries is bounded.
@Suite(.serialized)
@MainActor
struct PersistentMetricsStorageBatchingTests {

    // MARK: - Helpers

    private func makeContainerAndActor() throws -> (ModelContainer, MetricsStoreActor) {
        let schema = Schema(MetricsModelTypes.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let actor = MetricsStoreActor(modelContainer: container)
        return (container, actor)
    }

    private func makeStorage(
        container: ModelContainer,
        actor: MetricsStoreActor,
        batchSize: Int = 2000
    ) -> PersistentMetricsStorage {
        PersistentMetricsStorage(
            metricsActor: actor,
            modelContainer: container,
            batchSize: batchSize,
            flushInterval: 3600,
            bufferCapacity: 8192
        )
    }

    // MARK: - Per-label observation counts

    @Test("1000 entries across 5 labels: each MetricDefinition.totalObservations == 200")
    func perLabelObservationCountsViaInsertBatched() async throws {
        let (container, actor) = try makeContainerAndActor()
        let storage = makeStorage(container: container, actor: actor)

        let labels = ["alpha", "beta", "gamma", "delta", "epsilon"]
        let entriesPerLabel = 200

        for label in labels {
            for i in 0..<entriesPerLabel {
                storage.record(MetricEntry(
                    label: label,
                    dimensions: [],
                    type: .counter,
                    value: Double(i)
                ))
            }
        }
        await storage._testWaitForPendingAppends()
        await storage.flushNow()

        // Verify via direct actor query so we bypass the main-context read
        let defs = try await actor.discover()
        #expect(defs.count == labels.count)

        for def in defs {
            #expect(
                def.totalObservations == entriesPerLabel,
                "Expected \(entriesPerLabel) observations for \(def.label), got \(def.totalObservations)"
            )
        }
    }

    // MARK: - insertBatched ↔ insert parity

    @Test("insertBatched and insert(_:) produce identical MetricDefinition state")
    func insertBatchedParityWithInsert() async throws {
        let labels = ["parity.a", "parity.b", "parity.c"]
        let dims = [("env", "test"), ("region", "us-west")]

        // Build the same set of DTOs
        var dtos: [MetricObservationDTO] = []
        for label in labels {
            for i in 0..<10 {
                dtos.append(MetricObservationDTO(entry: MetricEntry(
                    timestamp: Date(timeIntervalSince1970: Double(i) * 60),
                    label: label,
                    dimensions: dims,
                    type: .counter,
                    value: Double(i)
                )))
            }
        }

        // --- Insert path ---
        let (containerA, actorA) = try makeContainerAndActor()
        try await actorA.insert(dtos)
        let defsA = try await actorA.discover()
        let sortedA = defsA.sorted { $0.label < $1.label }

        // --- InsertBatched path ---
        let (containerB, actorB) = try makeContainerAndActor()
        _ = containerB  // suppress unused warning
        try await actorB.insertBatched(dtos)
        let defsB = try await actorB.discover()
        let sortedB = defsB.sorted { $0.label < $1.label }

        #expect(sortedA.count == sortedB.count)
        for (a, b) in zip(sortedA, sortedB) {
            #expect(a.label == b.label)
            #expect(a.typeRawValue == b.typeRawValue)
            #expect(a.totalObservations == b.totalObservations,
                    "totalObservations mismatch for \(a.label): insert=\(a.totalObservations) insertBatched=\(b.totalObservations)")
            // Decode and sort dimension keys for comparison
            let keysA = (try? JSONDecoder().decode([String].self, from: Data(a.knownDimensionKeysJSON.utf8)))?.sorted() ?? []
            let keysB = (try? JSONDecoder().decode([String].self, from: Data(b.knownDimensionKeysJSON.utf8)))?.sorted() ?? []
            #expect(keysA == keysB,
                    "knownDimensionKeys mismatch for \(a.label): \(keysA) vs \(keysB)")
        }
    }

    // MARK: - Wall-time bound

    @Test("1000 inserts across 10 labels complete insertBatched within 5 seconds")
    func insertBatchedWallTimeBound() async throws {
        let (_, actor) = try makeContainerAndActor()

        var dtos: [MetricObservationDTO] = []
        for labelIndex in 0..<10 {
            for i in 0..<100 {
                dtos.append(MetricObservationDTO(entry: MetricEntry(
                    label: "perf.label.\(labelIndex)",
                    dimensions: [("run", "\(i % 5)")],
                    type: .counter,
                    value: Double(i)
                )))
            }
        }

        let clock = ContinuousClock()
        let elapsed = try await clock.measure {
            try await actor.insertBatched(dtos)
        }

        // 5 seconds is generous; the original 4 s Tenrec observation was for 10× more data.
        // This guards against catastrophic regression without being CI-speed-sensitive.
        #expect(
            elapsed < .seconds(5),
            "insertBatched took \(elapsed) — expected < 5s"
        )
    }

    // MARK: - Dimension key union

    @Test("insertBatched unions dimension keys across DTOs in the same group")
    func dimensionKeyUnionAcrossGroup() async throws {
        let (_, actor) = try makeContainerAndActor()

        // Two DTOs for "dim.test", different dimension keys
        let dto1 = MetricObservationDTO(entry: MetricEntry(
            label: "dim.test",
            dimensions: [("env", "prod")],
            type: .counter,
            value: 1
        ))
        let dto2 = MetricObservationDTO(entry: MetricEntry(
            label: "dim.test",
            dimensions: [("region", "eu")],
            type: .counter,
            value: 2
        ))

        try await actor.insertBatched([dto1, dto2])
        let defs = try await actor.discover()
        #expect(defs.count == 1)

        let keys = (try? JSONDecoder().decode([String].self, from: Data(defs[0].knownDimensionKeysJSON.utf8)))?.sorted() ?? []
        #expect(keys == ["env", "region"])
    }
}
