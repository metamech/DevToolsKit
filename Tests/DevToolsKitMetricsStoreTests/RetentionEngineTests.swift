import Foundation
import SwiftData
import Testing

@testable import DevToolsKitMetrics
@testable import DevToolsKitMetricsStore

@Suite(.serialized)
@MainActor
struct RetentionEngineTests {
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

    @Test
    func hourlyRollupCreation() async throws {
        let (container, storage, engine) = try makeSetup()
        let twoHoursAgo = Date().addingTimeInterval(-7200)

        // Record entries in a completed hour
        for i in 0..<60 {
            storage.record(
                MetricEntry(
                    timestamp: twoHoursAgo.addingTimeInterval(Double(i) * 60),
                    label: "rollup.test",
                    dimensions: [],
                    type: .counter,
                    value: Double(i)
                ))
        }
        await storage.flushNow()

        await engine.runMaintenanceCycle()

        let context = container.mainContext
        let gran = "hourly"
        let descriptor = FetchDescriptor<MetricRollup>(
            predicate: #Predicate { $0.granularity == gran }
        )
        let rollups = try context.fetch(descriptor)
        #expect(!rollups.isEmpty)
        #expect(rollups.allSatisfy { $0.label == "rollup.test" })
    }

    @Test
    func rollupAggregationAccuracy() async throws {
        let (container, storage, engine) = try makeSetup()
        let calendar = Calendar.current

        // Create entries in a single completed hour: 10 entries, values 1-10
        let threeHoursAgo = calendar.date(
            byAdding: .hour, value: -3, to: Date()
        )!
        let hourStart = calendar.date(
            bySettingHour: calendar.component(.hour, from: threeHoursAgo),
            minute: 0, second: 0, of: threeHoursAgo
        )!

        for i in 1...10 {
            storage.record(
                MetricEntry(
                    timestamp: hourStart.addingTimeInterval(Double(i) * 60),
                    label: "accuracy",
                    dimensions: [],
                    type: .counter,
                    value: Double(i)
                ))
        }
        await storage.flushNow()

        await engine.runMaintenanceCycle()

        let context = container.mainContext
        let lbl = "accuracy"
        let gran = "hourly"
        let descriptor = FetchDescriptor<MetricRollup>(
            predicate: #Predicate { $0.label == lbl && $0.granularity == gran }
        )
        let rollups = try context.fetch(descriptor)
        #expect(!rollups.isEmpty)

        if let rollup = rollups.first {
            #expect(rollup.count == 10)
            #expect(rollup.sum == 55)  // 1+2+...+10
            #expect(rollup.min == 1)
            #expect(rollup.max == 10)
            #expect(rollup.avg == 5.5)
        }
    }

    @Test
    func ttlPurging() async throws {
        let policy = RetentionPolicy(
            rawDataTTL: 3600,  // 1 hour
            hourlyRollupTTL: 7200,  // 2 hours
            dailyRollupTTL: 86400
        )
        let (container, storage, engine) = try makeSetup(policy: policy)

        // Record old entry (2 hours ago — should be purged with 1h TTL)
        storage.record(
            MetricEntry(
                timestamp: Date().addingTimeInterval(-7200),
                label: "old",
                dimensions: [],
                type: .counter,
                value: 1
            ))
        // Record recent entry (5 min ago — should survive)
        storage.record(
            MetricEntry(
                timestamp: Date().addingTimeInterval(-300),
                label: "recent",
                dimensions: [],
                type: .counter,
                value: 2
            ))
        await storage.flushNow()

        await engine.runMaintenanceCycle()

        let context = container.mainContext
        let observations = try context.fetch(FetchDescriptor<MetricObservation>())
        // Only the recent entry should remain
        #expect(observations.allSatisfy { $0.label == "recent" })
    }
}
