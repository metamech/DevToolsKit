import Foundation
import SwiftData
import Testing

@testable import DevToolsKitMetrics
@testable import DevToolsKitMetricsStore

@Suite(.serialized)
@MainActor
struct MetricObservationTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(MetricsModelTypes.all)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test
    func createObservation() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let obs = MetricObservation(
            label: "http.requests",
            typeRawValue: "counter",
            value: 42.0,
            dimensionsKey: "env=prod"
        )
        context.insert(obs)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MetricObservation>())
        #expect(fetched.count == 1)
        #expect(fetched[0].label == "http.requests")
        #expect(fetched[0].value == 42.0)
    }

    @Test
    func roundtripFromMetricEntry() throws {
        let entry = MetricEntry(
            timestamp: Date(),
            label: "request.duration",
            dimensions: [("region", "us"), ("env", "prod")],
            type: .timer,
            value: 125.5
        )

        let obs = MetricObservation(entry: entry)
        #expect(obs.label == "request.duration")
        #expect(obs.typeRawValue == "timer")
        #expect(obs.value == 125.5)
        #expect(obs.observationID == entry.id)
        // Dimensions should be sorted by key
        #expect(obs.dimensionsKey == "env=prod,region=us")

        let roundtripped = obs.toMetricEntry()
        #expect(roundtripped.id == entry.id)
        #expect(roundtripped.label == entry.label)
        #expect(roundtripped.type == entry.type)
        #expect(roundtripped.value == entry.value)
    }

    @Test
    func canonicalDimensionsKey() {
        let entry = MetricEntry(
            label: "test",
            dimensions: [("z", "3"), ("a", "1"), ("m", "2")],
            type: .counter,
            value: 1
        )
        let obs = MetricObservation(entry: entry)
        #expect(obs.dimensionsKey == "a=1,m=2,z=3")
    }

    @Test
    func emptyDimensions() {
        let entry = MetricEntry(
            label: "test",
            dimensions: [],
            type: .counter,
            value: 1
        )
        let obs = MetricObservation(entry: entry)
        #expect(obs.dimensionsKey == "")
        #expect(obs.dimensions.isEmpty)
    }
}
