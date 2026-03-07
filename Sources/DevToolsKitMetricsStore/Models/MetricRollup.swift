import Foundation
import SwiftData

/// Pre-aggregated metric bucket for efficient historical queries.
///
/// Rollups are created by the ``RetentionEngine`` from raw observations or
/// lower-granularity rollups. They trade detail for query speed.
///
/// > Since: 0.3.0
@Model
public final class MetricRollup {
    #Index<MetricRollup>([\.label, \.granularity, \.bucketStart])
    /// The metric label this rollup covers.
    public var label: String
    /// Raw value of the ``MetricType`` enum.
    public var typeRawValue: String
    /// Canonical sorted key of dimensions.
    public var dimensionsKey: String
    /// Granularity level: "hourly" or "daily".
    public var granularity: String
    /// Start of the time bucket (inclusive).
    public var bucketStart: Date
    /// End of the time bucket (exclusive).
    public var bucketEnd: Date
    /// Number of observations aggregated into this bucket.
    public var count: Int
    /// Sum of all values in this bucket.
    public var sum: Double
    /// Minimum value in this bucket.
    public var min: Double
    /// Maximum value in this bucket.
    public var max: Double
    /// Weighted average of values in this bucket.
    public var avg: Double

    public init(
        label: String,
        typeRawValue: String,
        dimensionsKey: String,
        granularity: String,
        bucketStart: Date,
        bucketEnd: Date,
        count: Int,
        sum: Double,
        min: Double,
        max: Double,
        avg: Double
    ) {
        self.label = label
        self.typeRawValue = typeRawValue
        self.dimensionsKey = dimensionsKey
        self.granularity = granularity
        self.bucketStart = bucketStart
        self.bucketEnd = bucketEnd
        self.count = count
        self.sum = sum
        self.min = min
        self.max = max
        self.avg = avg
    }
}
