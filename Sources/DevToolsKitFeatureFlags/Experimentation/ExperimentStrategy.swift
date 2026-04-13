import Foundation

/// A ``FlagResolutionStrategy`` that assigns users to experiment cohorts.
///
/// Flags that have an experiment configuration are resolved by deterministic
/// bucketing via ``CohortResolver``. Flags without experiments are deferred.
public final class ExperimentStrategy: FlagResolutionStrategy, Sendable {
    private let enrollment: EnrollmentID
    private let experiments: [String: CohortDefinition]

    public let name = "Experiment"

    /// - Parameters:
    ///   - enrollment: The enrollment ID manager for cohort bucketing.
    ///   - experiments: Map of flagID -> experiment definition.
    public init(enrollment: EnrollmentID, experiments: [String: CohortDefinition]) {
        self.enrollment = enrollment
        self.experiments = experiments
    }

    @MainActor public func resolve(_ flag: FeatureFlag) -> Bool? {
        guard let experiment = experiments[flag.id] else { return nil }
        let eligible = experiment.targeting.allSatisfy { $0.isSatisfied() }
        guard eligible else { return nil }

        let cohort = CohortResolver.assignCohort(
            enrollmentID: enrollment.value,
            flagID: flag.id,
            cohorts: experiment.cohorts
        )
        return cohort != nil
    }

    @MainActor public func detail(for flag: FeatureFlag) -> String? {
        guard let experiment = experiments[flag.id] else { return nil }
        let eligible = experiment.targeting.allSatisfy { $0.isSatisfied() }
        guard eligible else { return nil }

        let cohort = CohortResolver.assignCohort(
            enrollmentID: enrollment.value,
            flagID: flag.id,
            cohorts: experiment.cohorts
        )
        return cohort.map { "cohort: \($0)" }
    }
}
