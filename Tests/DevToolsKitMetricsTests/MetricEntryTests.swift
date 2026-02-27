import Foundation
import Testing

@testable import DevToolsKitMetrics

@Suite(.serialized)
@MainActor
struct MetricEntryTests {
    @Test func createEntry() {
        let entry = MetricEntry(
            label: "http.requests",
            dimensions: [("method", "GET"), ("path", "/api")],
            type: .counter,
            value: 42
        )

        #expect(entry.label == "http.requests")
        #expect(entry.type == .counter)
        #expect(entry.value == 42)
        #expect(entry.dimensions.count == 2)
        #expect(entry.dimensions[0].0 == "method")
        #expect(entry.dimensions[0].1 == "GET")
    }

    @Test func codableRoundTrip() throws {
        let entry = MetricEntry(
            label: "db.queries",
            dimensions: [("table", "users"), ("operation", "select")],
            type: .timer,
            value: 1_500_000
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(entry)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MetricEntry.self, from: data)

        #expect(decoded.id == entry.id)
        #expect(decoded.label == entry.label)
        #expect(decoded.type == entry.type)
        #expect(decoded.value == entry.value)
        #expect(decoded.dimensions.count == 2)
        #expect(decoded.dimensions[0].0 == "table")
        #expect(decoded.dimensions[0].1 == "users")
        #expect(decoded.dimensions[1].0 == "operation")
        #expect(decoded.dimensions[1].1 == "select")
    }

    @Test func identifierFromEntry() {
        let entry = MetricEntry(
            label: "http.latency",
            dimensions: [("method", "POST")],
            type: .recorder,
            value: 100
        )
        let identifier = MetricIdentifier(entry: entry)

        #expect(identifier.label == "http.latency")
        #expect(identifier.type == .recorder)
        #expect(identifier.dimensions.count == 1)
    }

    @Test func identifierEqualityIgnoresDimensionOrder() {
        let id1 = MetricIdentifier(
            label: "test",
            dimensions: [("a", "1"), ("b", "2")],
            type: .counter
        )
        let id2 = MetricIdentifier(
            label: "test",
            dimensions: [("b", "2"), ("a", "1")],
            type: .counter
        )

        #expect(id1 == id2)
        #expect(id1.hashValue == id2.hashValue)
    }

    @Test func identifierCodableRoundTrip() throws {
        let identifier = MetricIdentifier(
            label: "http.requests",
            dimensions: [("method", "GET")],
            type: .counter
        )

        let data = try JSONEncoder().encode(identifier)
        let decoded = try JSONDecoder().decode(MetricIdentifier.self, from: data)

        #expect(decoded == identifier)
    }
}
