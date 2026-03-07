import DevToolsKitMetrics
import Foundation
import SwiftData

/// A single recorded metric data point persisted via SwiftData.
///
/// > Since: 0.3.0
@Model
public final class MetricObservation {
    /// Unique identifier for this observation.
    #Index<MetricObservation>([\.label], [\.timestamp], [\.label, \.timestamp])
    public var observationID: UUID
    /// When the observation was recorded.
    public var timestamp: Date
    /// The metric label (e.g. "http.requests.total").
    public var label: String
    /// Raw value of the ``MetricType`` enum.
    public var typeRawValue: String
    /// The recorded numeric value.
    public var value: Double
    /// Canonical sorted key representation of dimensions (e.g. "env=prod,region=us").
    public var dimensionsKey: String
    /// The key-value dimension pairs for this observation.
    @Relationship(deleteRule: .cascade, inverse: \MetricDimension.observation)
    public var dimensions: [MetricDimension]

    public init(
        observationID: UUID = UUID(),
        timestamp: Date = Date(),
        label: String,
        typeRawValue: String,
        value: Double,
        dimensionsKey: String,
        dimensions: [MetricDimension] = []
    ) {
        self.observationID = observationID
        self.timestamp = timestamp
        self.label = label
        self.typeRawValue = typeRawValue
        self.value = value
        self.dimensionsKey = dimensionsKey
        self.dimensions = dimensions
    }
}

extension MetricObservation {
    /// Creates a ``MetricObservation`` from a ``MetricEntry``.
    public convenience init(entry: MetricEntry) {
        let dims = entry.dimensions.sorted { $0.0 < $1.0 }
        let key = dims.map { "\($0.0)=\($0.1)" }.joined(separator: ",")
        self.init(
            observationID: entry.id,
            timestamp: entry.timestamp,
            label: entry.label,
            typeRawValue: entry.type.rawValue,
            value: entry.value,
            dimensionsKey: key,
            dimensions: dims.map { MetricDimension(key: $0.0, value: $0.1) }
        )
    }

    /// Converts this observation back to a ``MetricEntry``.
    public func toMetricEntry() -> MetricEntry {
        MetricEntry(
            id: observationID,
            timestamp: timestamp,
            label: label,
            dimensions: dimensions.map { ($0.key, $0.value) },
            type: MetricType(rawValue: typeRawValue) ?? .counter,
            value: value
        )
    }
}
