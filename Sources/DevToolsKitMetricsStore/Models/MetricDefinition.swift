import Foundation
import SwiftData

/// Registry entry for a known metric, tracking metadata and observation counts.
///
/// > Since: 0.3.0
@Model
public final class MetricDefinition {
    #Unique<MetricDefinition>([\.label, \.typeRawValue])
    /// The metric label.
    public var label: String
    /// Raw value of the ``MetricType`` enum.
    public var typeRawValue: String
    /// JSON-encoded array of known dimension key names.
    public var knownDimensionKeysJSON: String
    /// When this metric was first observed.
    public var firstSeenAt: Date
    /// When this metric was last observed.
    public var lastSeenAt: Date
    /// Total number of observations recorded for this metric.
    public var totalObservations: Int

    public init(
        label: String,
        typeRawValue: String,
        knownDimensionKeysJSON: String = "[]",
        firstSeenAt: Date = Date(),
        lastSeenAt: Date = Date(),
        totalObservations: Int = 0
    ) {
        self.label = label
        self.typeRawValue = typeRawValue
        self.knownDimensionKeysJSON = knownDimensionKeysJSON
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.totalObservations = totalObservations
    }
}
