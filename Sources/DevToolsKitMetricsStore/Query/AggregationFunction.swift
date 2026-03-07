import Foundation

/// Aggregation function for computing a single value from a group of observations.
///
/// > Since: 0.3.0
public enum AggregationFunction: Sendable {
    /// Sum of all values.
    case sum
    /// Arithmetic mean.
    case avg
    /// Minimum value.
    case min
    /// Maximum value.
    case max
    /// Number of observations.
    case count
    /// Most recent value by timestamp.
    case latest
    /// 50th percentile (median).
    case p50
    /// 95th percentile.
    case p95
    /// 99th percentile.
    case p99

    /// Compute this aggregation over the given values.
    ///
    /// - Parameters:
    ///   - values: The values to aggregate. Must not be empty.
    ///   - timestamps: Corresponding timestamps, required for `.latest`.
    /// - Returns: The aggregated result, or `nil` if values is empty.
    func compute(_ values: [Double], timestamps: [Date] = []) -> Double? {
        guard !values.isEmpty else { return nil }
        switch self {
        case .sum: return values.reduce(0, +)
        case .avg: return values.reduce(0, +) / Double(values.count)
        case .min: return values.min()
        case .max: return values.max()
        case .count: return Double(values.count)
        case .latest:
            if timestamps.count == values.count,
                let maxIndex = timestamps.indices.max(by: { timestamps[$0] < timestamps[$1] })
            {
                return values[maxIndex]
            } else {
                return values.last
            }
        case .p50: return Self.percentile(values.sorted(), p: 0.50)
        case .p95: return Self.percentile(values.sorted(), p: 0.95)
        case .p99: return Self.percentile(values.sorted(), p: 0.99)
        }
    }

    private static func percentile(_ sorted: [Double], p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let index = p * Double(sorted.count - 1)
        let lower = Int(index)
        let upper = Swift.min(lower + 1, sorted.count - 1)
        let fraction = index - Double(lower)
        return sorted[lower] + fraction * (sorted[upper] - sorted[lower])
    }
}
