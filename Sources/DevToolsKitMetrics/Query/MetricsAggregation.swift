import Foundation

/// Utilities for aggregating metric entries into summaries and time-series data.
public enum MetricsAggregation {
    /// Compute summary statistics for a collection of entries sharing the same identifier.
    ///
    /// Returns `nil` if the entries array is empty.
    public static func summarize(
        _ entries: [MetricEntry],
        identifier: MetricIdentifier
    ) -> MetricSummary? {
        guard let first = entries.first else { return nil }

        var sum = 0.0
        var minVal = first.value
        var maxVal = first.value
        var latest = first
        let values = entries.map(\.value)

        for entry in entries {
            sum += entry.value
            if entry.value < minVal { minVal = entry.value }
            if entry.value > maxVal { maxVal = entry.value }
            if entry.timestamp > latest.timestamp { latest = entry }
        }

        let count = entries.count
        let avg = sum / Double(count)

        // Percentiles via sorted values
        let sorted = values.sorted()
        let p50 = percentile(sorted, p: 0.50)
        let p95 = percentile(sorted, p: 0.95)
        let p99 = percentile(sorted, p: 0.99)

        return MetricSummary(
            identifier: identifier,
            count: count,
            sum: sum,
            min: minVal,
            max: maxVal,
            avg: avg,
            latest: latest.value,
            latestTimestamp: latest.timestamp,
            p50: p50,
            p95: p95,
            p99: p99
        )
    }

    /// Group entries by time interval and compute per-bucket averages.
    ///
    /// Returns an array of `(date, average, count)` tuples sorted by date ascending.
    public static func groupByInterval(
        _ entries: [MetricEntry],
        interval: TimeInterval
    ) -> [(date: Date, avg: Double, count: Int)] {
        guard !entries.isEmpty else { return [] }

        var buckets: [Date: (sum: Double, count: Int)] = [:]

        for entry in entries {
            let bucketStart = Date(
                timeIntervalSinceReferenceDate:
                    (entry.timestamp.timeIntervalSinceReferenceDate / interval).rounded(.down) * interval
            )
            var bucket = buckets[bucketStart, default: (sum: 0.0, count: 0)]
            bucket.sum += entry.value
            bucket.count += 1
            buckets[bucketStart] = bucket
        }

        return buckets
            .map { (date: $0.key, avg: $0.value.sum / Double($0.value.count), count: $0.value.count) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Private

    private static func percentile(_ sorted: [Double], p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let index = p * Double(sorted.count - 1)
        let lower = Int(index)
        let upper = Swift.min(lower + 1, sorted.count - 1)
        let fraction = index - Double(lower)
        return sorted[lower] + fraction * (sorted[upper] - sorted[lower])
    }
}
