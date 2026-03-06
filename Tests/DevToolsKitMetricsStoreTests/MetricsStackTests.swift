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
    func endToEndRecordAndQuery() throws {
        let stack = try MetricsStack.create(inMemory: true)

        stack.storage.record(
            MetricEntry(
                label: "e2e.test",
                dimensions: [("env", "test")],
                type: .counter,
                value: 42
            ))

        let result = stack.database.execute(
            DatabaseQuery(
                labelFilter: .exact("e2e.test")
            ))
        #expect(result.rows.count == 1)
        #expect(result.rows[0].value == 42)
    }

    @Test
    func customBatchSize() throws {
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

        let result = stack.database.execute(
            DatabaseQuery(
                labelFilter: .exact("batch"),
                aggregation: .count
            ))
        #expect(result.rows[0].value == 10)
    }
}
