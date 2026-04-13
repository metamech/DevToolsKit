import CoreMetrics

/// Default ``FlagMetricsHandler`` that emits events through the swift-metrics API.
///
/// This is a drop-in replacement for the previous `FlagMetrics` enum.
public struct SwiftMetricsFlagMetricsHandler: FlagMetricsHandler, Sendable {
    public init() {}

    public func recordCheck(flagID: String, result: Bool) {
        Counter(
            label: "devtools.feature_flag.check",
            dimensions: [("flag_id", flagID), ("result", "\(result)")]
        ).increment()
    }

    public func recordOverride(flagID: String, value: Bool) {
        Counter(
            label: "devtools.feature_flag.override",
            dimensions: [("flag_id", flagID), ("value", "\(value)")]
        ).increment()
    }

    public func recordCohortAssignment(flagID: String, cohort: String) {
        Counter(
            label: "devtools.feature_flag.cohort_assignment",
            dimensions: [("flag_id", flagID), ("cohort", cohort)]
        ).increment()
    }
}
