import CoreMetrics

/// Emits feature flag events through the swift-metrics API.
///
/// Events are recorded as counters. A future `DevToolsKitMetrics` module can register
/// a `MetricsFactory` backend to collect them, mirroring how `DevToolsKitLogging`
/// registers a `LogHandler` for swift-log.
public enum FlagMetrics {
    /// Record a flag check event.
    ///
    /// - Parameters:
    ///   - flagID: The feature flag's stable identifier.
    ///   - result: Whether the flag resolved to enabled.
    public static func recordCheck(flagID: String, result: Bool) {
        Counter(
            label: "devtools.feature_flag.check",
            dimensions: [("flag_id", flagID), ("result", "\(result)")]
        ).increment()
    }

    /// Record a cohort assignment event.
    ///
    /// - Parameters:
    ///   - flagID: The feature flag's stable identifier.
    ///   - cohort: The assigned cohort name.
    public static func recordCohortAssignment(flagID: String, cohort: String) {
        Counter(
            label: "devtools.feature_flag.cohort_assignment",
            dimensions: [("flag_id", flagID), ("cohort", cohort)]
        ).increment()
    }

    /// Record an override event.
    ///
    /// - Parameters:
    ///   - flagID: The feature flag's stable identifier.
    ///   - value: The override value.
    public static func recordOverride(flagID: String, value: Bool) {
        Counter(
            label: "devtools.feature_flag.override",
            dimensions: [("flag_id", flagID), ("value", "\(value)")]
        ).increment()
    }
}
