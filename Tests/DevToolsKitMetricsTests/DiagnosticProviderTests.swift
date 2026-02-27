import DevToolsKit
import Foundation
import Testing

@testable import DevToolsKitMetrics

@Suite(.serialized)
@MainActor
struct DiagnosticProviderTests {
    @Test func sectionName() {
        let manager = MetricsManager()
        let provider: any DiagnosticProvider = manager
        #expect(provider.sectionName == "metrics")
    }

    @Test func collectReturnsMetricSummaries() async {
        let store = InMemoryMetricsStorage()
        store.record(MetricEntry(label: "http.requests", dimensions: [], type: .counter, value: 10))
        store.record(MetricEntry(label: "http.requests", dimensions: [], type: .counter, value: 20))
        store.record(MetricEntry(label: "db.latency", dimensions: [], type: .timer, value: 5000))

        let manager = MetricsManager(storage: store)
        let result = await manager.collect()

        // The result should be encodable to JSON
        let data = try? JSONEncoder().encode(AnyEncodable(result))
        #expect(data != nil)

        // Decode back to check structure
        if let data {
            let entries = try? JSONDecoder().decode([DiagnosticEntry].self, from: data)
            #expect(entries != nil)
            #expect(entries?.count == 2)

            if let httpEntry = entries?.first(where: { $0.label == "http.requests" }) {
                #expect(httpEntry.type == "counter")
                #expect(httpEntry.count == 2)
                #expect(httpEntry.avg == 15)
            }
        }
    }
}

// MARK: - Test Helpers

private struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void

    init(_ value: any Encodable) {
        self.encode = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}

private struct DiagnosticEntry: Decodable {
    let label: String
    let type: String
    let count: Int
    let latest: Double
    let avg: Double
    let min: Double
    let max: Double
}
