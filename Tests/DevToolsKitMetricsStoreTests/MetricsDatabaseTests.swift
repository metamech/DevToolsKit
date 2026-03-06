import Foundation
import SwiftData
import Testing

@testable import DevToolsKitMetrics
@testable import DevToolsKitMetricsStore

@Suite(.serialized)
@MainActor
struct MetricsDatabaseTests {
    private func makeStack() throws -> MetricsStack {
        try MetricsStack.create(inMemory: true, batchSize: 1000)
    }

    @Test
    func execute() throws {
        let stack = try makeStack()

        for i in 0..<5 {
            stack.storage.record(MetricEntry(
                label: "test", dimensions: [], type: .counter, value: Double(i + 1)
            ))
        }
        stack.storage.flushNow()

        let result = stack.database.execute(DatabaseQuery(
            labelFilter: .exact("test"),
            aggregation: .sum
        ))
        #expect(result.rows.count == 1)
        #expect(result.rows[0].value == 15)
    }

    @Test
    func discoverWithPrefix() throws {
        let stack = try makeStack()

        stack.storage.record(MetricEntry(label: "http.req", dimensions: [], type: .counter, value: 1))
        stack.storage.record(MetricEntry(label: "http.err", dimensions: [], type: .counter, value: 1))
        stack.storage.record(MetricEntry(label: "db.query", dimensions: [], type: .timer, value: 1))
        stack.storage.flushNow()

        let httpMetrics = stack.database.discover(prefix: "http.")
        #expect(httpMetrics.count == 2)
        #expect(httpMetrics.allSatisfy { $0.label.hasPrefix("http.") })

        let allMetrics = stack.database.discover()
        #expect(allMetrics.count == 3)
    }

    @Test
    func summaryForLabel() throws {
        let stack = try makeStack()

        for v in [10.0, 20.0, 30.0] {
            stack.storage.record(MetricEntry(
                label: "latency", dimensions: [], type: .timer, value: v
            ))
        }

        let summary = stack.database.summary(for: "latency")
        #expect(summary != nil)
        #expect(summary?.count == 3)
        #expect(summary?.avg == 20)
        #expect(summary?.min == 10)
        #expect(summary?.max == 30)
    }

    @Test
    func summaryForLabelWithType() throws {
        let stack = try makeStack()

        stack.storage.record(MetricEntry(label: "m", dimensions: [], type: .counter, value: 5))
        stack.storage.record(MetricEntry(label: "m", dimensions: [], type: .timer, value: 100))

        let counterSummary = stack.database.summary(for: "m", type: .counter)
        #expect(counterSummary?.count == 1)
        #expect(counterSummary?.sum == 5)
    }

    @Test
    func rateCalculation() throws {
        let stack = try makeStack()
        let now = Date()

        // Counter incrementing by 10 per second, in the past
        for i in 0..<10 {
            stack.storage.record(MetricEntry(
                timestamp: now.addingTimeInterval(Double(i) - 20),
                label: "counter",
                dimensions: [],
                type: .counter,
                value: Double(i * 10)
            ))
        }

        let rate = stack.database.rate(label: "counter", over: 30)
        #expect(rate != nil)
        #expect(abs(rate! - 10.0) < 0.001) // ~10 per second
    }

    @Test
    func rateWithInsufficientData() throws {
        let stack = try makeStack()

        stack.storage.record(MetricEntry(
            label: "single", dimensions: [], type: .counter, value: 5
        ))

        let rate = stack.database.rate(label: "single", over: 60)
        #expect(rate == nil)
    }

    @Test
    func streamEmitsInitialResult() async throws {
        let stack = try makeStack()

        stack.storage.record(MetricEntry(
            label: "streamed", dimensions: [], type: .counter, value: 42
        ))
        stack.storage.flushNow()

        let stream = stack.database.stream(DatabaseQuery(
            labelFilter: .exact("streamed")
        ))

        var receivedFirst = false
        for await result in stream {
            #expect(result.rows.count == 1)
            #expect(result.rows[0].value == 42)
            receivedFirst = true
            break
        }
        #expect(receivedFirst)
    }
}
