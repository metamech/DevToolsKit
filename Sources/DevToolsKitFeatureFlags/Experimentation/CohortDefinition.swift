import Foundation

/// A single cohort within a multi-cohort experiment.
///
/// Weights are relative — they do not need to sum to 100. The ``CohortResolver``
/// normalizes them into cumulative bucket ranges (0–99).
public struct Cohort: Sendable, Hashable, Codable {
    /// Display name for this cohort (e.g., `"control"`, `"variant-a"`).
    public let name: String

    /// Relative weight for bucket assignment.
    public let weight: Int

    /// - Parameters:
    ///   - name: Cohort name used in flag state and analytics.
    ///   - weight: Relative weight; higher values mean more users are assigned.
    public init(name: String, weight: Int) {
        self.name = name
        self.weight = weight
    }
}

/// Configuration for a multi-cohort experiment attached to a feature flag.
///
/// Users are deterministically assigned to a cohort based on their enrollment ID
/// and the flag ID. Users who do not meet the targeting rules fall back to the
/// flag's ``FeatureFlagDefinition/defaultEnabled`` value.
public struct CohortDefinition: Sendable, Hashable, Codable {
    /// The cohorts in this experiment.
    public let cohorts: [Cohort]

    /// Targeting rules that must all be satisfied for a user to be enrolled.
    public let targeting: [TargetingRule]

    /// - Parameters:
    ///   - cohorts: The cohorts with their relative weights.
    ///   - targeting: Rules that gate enrollment; defaults to no restrictions.
    public init(cohorts: [Cohort], targeting: [TargetingRule] = []) {
        self.cohorts = cohorts
        self.targeting = targeting
    }
}
