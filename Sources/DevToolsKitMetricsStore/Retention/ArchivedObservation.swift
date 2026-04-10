import Foundation

/// Sendable value-type snapshot of a MetricObservation for archival.
///
/// Extracted on the actor before crossing async boundaries, eliminating
/// the need to pass live `@Model` objects via `nonisolated(unsafe)`.
///
/// > Since: 0.12.0
public struct ArchivedObservation: Sendable {
    public let timestamp: Date
    public let label: String
    public let typeRawValue: String
    public let value: Double
    public let dimensions: [(key: String, value: String)]

    public init(
        timestamp: Date,
        label: String,
        typeRawValue: String,
        value: Double,
        dimensions: [(key: String, value: String)]
    ) {
        self.timestamp = timestamp
        self.label = label
        self.typeRawValue = typeRawValue
        self.value = value
        self.dimensions = dimensions
    }
}
