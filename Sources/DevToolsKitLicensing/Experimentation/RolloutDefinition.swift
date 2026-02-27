import Foundation

/// Configuration for a percentage-based gradual rollout of a feature flag.
///
/// Users are deterministically bucketed (0–99) based on their enrollment ID
/// and the flag ID. If `bucket < percentage`, the flag is enabled.
/// Users who do not meet the targeting rules fall back to the flag's
/// ``FeatureFlagDefinition/defaultEnabled`` value.
public struct RolloutDefinition: Sendable, Hashable, Codable {
    /// Percentage of eligible users who should have this flag enabled (0–100).
    public let percentage: Int

    /// Targeting rules that must all be satisfied for a user to be in the rollout.
    public let targeting: [TargetingRule]

    /// - Parameters:
    ///   - percentage: Percentage of eligible users (0–100) to enable the flag for.
    ///   - targeting: Rules that gate eligibility; defaults to no restrictions.
    public init(percentage: Int, targeting: [TargetingRule] = []) {
        self.percentage = min(max(percentage, 0), 100)
        self.targeting = targeting
    }
}
