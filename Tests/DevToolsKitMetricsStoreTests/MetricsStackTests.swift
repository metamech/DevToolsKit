import Foundation
import SwiftData
import Testing

@testable import DevToolsKitMetrics
@testable import DevToolsKitMetricsStore

@Suite(.serialized)
@MainActor
struct MetricsStackTests {
    @Test
    func createInMemory() throws {
        let stack = try MetricsStack.create(inMemory: true)
        #expect(stack.storage.entryCount == 0)
    }

    @Test
    func modelTypesCompleteness() {
        let types = MetricsStack.modelTypes
        #expect(types.count == 4)
        // Verify all expected types are present
        #expect(types.contains { $0 == MetricObservation.self })
        #expect(types.contains { $0 == MetricDimension.self })
        #expect(types.contains { $0 == MetricRollup.self })
        #expect(types.contains { $0 == MetricDefinition.self })
    }

    @Test
    func endToEndRecordAndQuery() async throws {
        let stack = try MetricsStack.create(inMemory: true)

        stack.storage.record(
            MetricEntry(
                label: "e2e.test",
                dimensions: [("env", "test")],
                type: .counter,
                value: 42
            ))

        // record() is fire-and-forget — wait for the entry to reach the BufferActor,
        // then flush so it lands in SwiftData before querying.
        await stack.storage._testWaitForPendingAppends()
        await stack.storage.flushNow()

        let result = await stack.database.execute(
            DatabaseQuery(
                labelFilter: .exact("e2e.test")
            ))
        #expect(result.rows.count == 1)
        #expect(result.rows[0].value == 42)
    }

    @Test
    func customBatchSize() async throws {
        let stack = try MetricsStack.create(inMemory: true, batchSize: 5)

        for i in 0..<10 {
            stack.storage.record(
                MetricEntry(
                    label: "batch",
                    dimensions: [],
                    type: .counter,
                    value: Double(i)
                ))
        }

        // Wait for async batch flushes to complete — batchSize=5 so two auto-flush
        // Tasks are triggered. Give them time to complete.
        await stack.storage._testWaitForPendingAppends()
        try await Task.sleep(for: .milliseconds(200))

        let result = await stack.database.execute(
            DatabaseQuery(
                labelFilter: .exact("batch"),
                aggregation: .count
            ))
        #expect(result.rows[0].value == 10)
    }
}
