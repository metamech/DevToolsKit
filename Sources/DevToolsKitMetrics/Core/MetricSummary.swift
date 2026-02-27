import Foundation

/// Aggregated statistics for a single metric identifier.
public struct MetricSummary: Identifiable, Sendable {
    /// Stable identity based on the metric identifier.
    public var id: MetricIdentifier { identifier }
    /// The metric this summary describes.
    public let identifier: MetricIdentifier
    /// Total number of recorded entries.
    public let count: Int
    /// Sum of all recorded values.
    public let sum: Double
    /// Minimum recorded value.
    public let min: Double
    /// Maximum recorded value.
    public let max: Double
    /// Arithmetic mean of recorded values.
    public let avg: Double
    /// Most recently recorded value.
    public let latest: Double
    /// Timestamp of the most recent entry.
    public let latestTimestamp: Date
    /// 50th percentile (median), if available.
    public let p50: Double?
    /// 95th percentile, if available.
    public let p95: Double?
    /// 99th percentile, if available.
    public let p99: Double?

    public init(
        identifier: MetricIdentifier,
        count: Int,
        sum: Double,
        min: Double,
        max: Double,
        avg: Double,
        latest: Double,
        latestTimestamp: Date,
        p50: Double? = nil,
        p95: Double? = nil,
        p99: Double? = nil
    ) {
        self.identifier = identifier
        self.count = count
        self.sum = sum
        self.min = min
        self.max = max
        self.avg = avg
        self.latest = latest
        self.latestTimestamp = latestTimestamp
        self.p50 = p50
        self.p95 = p95
        self.p99 = p99
    }
}
