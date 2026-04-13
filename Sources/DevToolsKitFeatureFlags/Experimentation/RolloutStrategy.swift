import Foundation

/// A ``FlagResolutionStrategy`` that enables flags for a percentage of users.
///
/// Flags that have a rollout configuration are resolved by deterministic
/// bucketing via ``CohortResolver``. Flags without rollouts are deferred.
public final class RolloutStrategy: FlagResolutionStrategy, Sendable {
    private let enrollment: EnrollmentID
    private let rollouts: [String: RolloutDefinition]

    public let name = "Rollout"

    /// - Parameters:
    ///   - enrollment: The enrollment ID manager for bucketing.
    ///   - rollouts: Map of flagID -> rollout definition.
    public init(enrollment: EnrollmentID, rollouts: [String: RolloutDefinition]) {
        self.enrollment = enrollment
        self.rollouts = rollouts
    }

    @MainActor public func resolve(_ flag: FeatureFlag) -> Bool? {
        guard let rollout = rollouts[flag.id] else { return nil }
        let eligible = rollout.targeting.allSatisfy { $0.isSatisfied() }
        guard eligible else { return nil }

        return CohortResolver.isInRollout(
            enrollmentID: enrollment.value,
            flagID: flag.id,
            percentage: rollout.percentage
        )
    }

    @MainActor public func detail(for flag: FeatureFlag) -> String? {
        guard let rollout = rollouts[flag.id] else { return nil }
        return "\(rollout.percentage)% rollout"
    }
}
