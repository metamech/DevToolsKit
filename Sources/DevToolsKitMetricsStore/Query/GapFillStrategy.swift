import Foundation

/// Strategy for filling gaps in time-bucketed query results.
///
/// When a time range is queried with a ``TimeBucket``, some buckets may have
/// no observations. The gap fill strategy controls what value is used for
/// those empty buckets.
///
/// > Since: 0.3.0
public enum GapFillStrategy: Sendable {
    /// No gap filling; empty buckets are omitted from results.
    case none
    /// Fill empty buckets with zero.
    case zero
    /// Fill empty buckets with the last known value.
    case carryForward
}
