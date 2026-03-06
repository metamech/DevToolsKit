import Foundation

/// Time interval granularity for bucketing metric observations.
///
/// > Since: 0.3.0
public enum TimeBucket: Sendable {
    /// 1-minute buckets.
    case minute
    /// 1-hour buckets.
    case hour
    /// 1-day buckets.
    case day
    /// 1-week buckets.
    case week
    /// Custom interval in seconds.
    case custom(TimeInterval)

    /// The interval in seconds for this bucket size.
    public var interval: TimeInterval {
        switch self {
        case .minute: 60
        case .hour: 3_600
        case .day: 86_400
        case .week: 604_800
        case .custom(let seconds): seconds
        }
    }

    /// Returns the start of the bucket containing the given date.
    func bucketStart(for date: Date) -> Date {
        let ref = date.timeIntervalSinceReferenceDate
        let bucketRef = (ref / interval).rounded(.down) * interval
        return Date(timeIntervalSinceReferenceDate: bucketRef)
    }
}
