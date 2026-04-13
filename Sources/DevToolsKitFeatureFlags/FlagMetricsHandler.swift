import Foundation

/// Protocol for recording feature flag metrics events.
///
/// Implement this protocol to bridge to your preferred metrics backend
/// (e.g., swift-metrics, custom analytics). Assign an instance to
/// ``FeatureFlagStore/metricsHandler``.
public protocol FlagMetricsHandler: Sendable {
    /// A flag was checked via ``FeatureFlagStore/isEnabled(_:)``.
    func recordCheck(flagID: String, result: Bool)

    /// A developer override was set via ``FeatureFlagStore/setOverride(_:for:expiresAfter:)``.
    func recordOverride(flagID: String, value: Bool)

    /// A cohort was assigned during experiment resolution.
    func recordCohortAssignment(flagID: String, cohort: String)
}
