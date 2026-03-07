import Foundation
import Testing

@testable import DevToolsKitMetrics
@testable import DevToolsKitMetricsStore

@Suite(.serialized)
@MainActor
struct RateCalculationTests {
    private func makeStack() throws -> MetricsStack {
        try MetricsStack.create(inMemory: true, batchSize: 1000)
    }

    @Test
    func steadyRate() throws {
        let stack = try makeStack()
        let now = Date()

        // 10 per second for 10 seconds, in the past
        for i in 0..<10 {
            stack.storage.record(
                MetricEntry(
                    timestamp: now.addingTimeInterval(Double(i) - 20),
                    label: "steady",
                    dimensions: [],
                    type: .counter,
                    value: Double(i * 10)
                ))
        }

        let rate = stack.database.rate(label: "steady", over: 30)
        #expect(rate != nil)
        #expect(abs(rate! - 10.0) < 0.01)
    }

    @Test
    func noDataReturnsNil() throws {
        let stack = try makeStack()
        let rate = stack.database.rate(label: "missing", over: 60)
        #expect(rate == nil)
    }

    @Test
    func singlePointReturnsNil() throws {
        let stack = try makeStack()

        stack.storage.record(
            MetricEntry(
                label: "single",
                dimensions: [],
                type: .counter,
                value: 42
            ))

        let rate = stack.database.rate(label: "single", over: 60)
        #expect(rate == nil)
    }

    @Test
    func decreasingRate() throws {
        let stack = try makeStack()
        let now = Date()

        // Decreasing counter (e.g., remaining capacity), in the past
        for i in 0..<5 {
            stack.storage.record(
                MetricEntry(
                    timestamp: now.addingTimeInterval(Double(i) * 2 - 20),
                    label: "decreasing",
                    dimensions: [],
                    type: .counter,
                    value: Double(100 - i * 20)
                ))
        }

        let rate = stack.database.rate(label: "decreasing", over: 30)
        #expect(rate != nil)
        #expect(rate! < 0)  // Negative rate
    }
}
