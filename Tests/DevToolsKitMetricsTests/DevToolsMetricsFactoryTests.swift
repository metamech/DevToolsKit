import Foundation
import Testing

@testable import DevToolsKitMetrics

@Suite(.serialized)
@MainActor
struct DevToolsMetricsFactoryTests {
    @Test func counterHandlerRecords() async throws {
        let store = InMemoryMetricsStorage()
        let factory = DevToolsMetricsFactory(storage: store)

        let handler = factory.makeCounter(label: "test.counter", dimensions: [("env", "test")])
        handler.increment(by: 5)

        try await Task.sleep(for: .milliseconds(350))
        #expect(store.entryCount == 1)
        let entry = store.query(MetricsQuery())[0]
        #expect(entry.label == "test.counter")
        #expect(entry.type == .counter)
        #expect(entry.value == 5)
    }

    @Test func floatingPointCounterHandlerRecords() async throws {
        let store = InMemoryMetricsStorage()
        let factory = DevToolsMetricsFactory(storage: store)

        let handler = factory.makeFloatingPointCounter(label: "test.fp_counter", dimensions: [])
        handler.increment(by: 3.14)

        try await Task.sleep(for: .milliseconds(350))
        #expect(store.entryCount == 1)
        let entry = store.query(MetricsQuery())[0]
        #expect(entry.type == .floatingPointCounter)
        #expect(entry.value == 3.14)
    }

    @Test func meterHandlerRecords() async throws {
        let store = InMemoryMetricsStorage()
        let factory = DevToolsMetricsFactory(storage: store)

        let handler = factory.makeMeter(label: "test.meter", dimensions: [])
        handler.set(42.0)

        try await Task.sleep(for: .milliseconds(350))
        #expect(store.entryCount == 1)
        let entry = store.query(MetricsQuery())[0]
        #expect(entry.type == .meter)
        #expect(entry.value == 42.0)
    }

    @Test func recorderHandlerRecords() async throws {
        let store = InMemoryMetricsStorage()
        let factory = DevToolsMetricsFactory(storage: store)

        let handler = factory.makeRecorder(label: "test.recorder", dimensions: [], aggregate: true)
        handler.record(Int64(100))

        try await Task.sleep(for: .milliseconds(350))
        #expect(store.entryCount == 1)
        let entry = store.query(MetricsQuery())[0]
        #expect(entry.type == .recorder)
        #expect(entry.value == 100)
    }

    @Test func timerHandlerRecords() async throws {
        let store = InMemoryMetricsStorage()
        let factory = DevToolsMetricsFactory(storage: store)

        let handler = factory.makeTimer(label: "test.timer", dimensions: [])
        handler.recordNanoseconds(1_000_000)

        try await Task.sleep(for: .milliseconds(350))
        #expect(store.entryCount == 1)
        let entry = store.query(MetricsQuery())[0]
        #expect(entry.type == .timer)
        #expect(entry.value == 1_000_000)
    }
}
