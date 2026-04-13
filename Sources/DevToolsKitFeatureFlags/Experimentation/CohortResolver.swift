import CryptoKit
import Foundation

/// Deterministically assigns users to cohorts or rollout buckets.
///
/// Uses a stable hash of `enrollmentID + flagID` to produce a bucket (0–99).
/// The same input always yields the same bucket, ensuring consistent assignment
/// across app launches.
public enum CohortResolver {
    /// Compute a stable bucket (0–99) from an enrollment ID and flag ID.
    ///
    /// - Parameters:
    ///   - enrollmentID: The user's enrollment UUID.
    ///   - flagID: The feature flag's stable identifier.
    /// - Returns: An integer in `0..<100`.
    public static func bucket(enrollmentID: UUID, flagID: String) -> Int {
        let input = "\(enrollmentID.uuidString):\(flagID)"
        let digest = SHA256.hash(data: Data(input.utf8))
        let firstFourBytes = digest.prefix(4)
        let value = firstFourBytes.reduce(0) { ($0 << 8) | UInt32($1) }
        return Int(value % 100)
    }

    /// Resolve which cohort a user belongs to in a multi-cohort experiment.
    ///
    /// - Parameters:
    ///   - enrollmentID: The user's enrollment UUID.
    ///   - flagID: The feature flag's stable identifier.
    ///   - cohorts: The experiment's cohort definitions.
    /// - Returns: The name of the assigned cohort, or `nil` if cohorts are empty.
    public static func assignCohort(
        enrollmentID: UUID, flagID: String, cohorts: [Cohort]
    ) -> String? {
        guard !cohorts.isEmpty else { return nil }
        let totalWeight = cohorts.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return cohorts.first?.name }

        let userBucket = bucket(enrollmentID: enrollmentID, flagID: flagID)
        let scaledBucket = userBucket * totalWeight / 100

        var cumulative = 0
        for cohort in cohorts {
            cumulative += cohort.weight
            if scaledBucket < cumulative {
                return cohort.name
            }
        }
        return cohorts.last?.name
    }

    /// Determine whether a user is within a percentage rollout.
    ///
    /// - Parameters:
    ///   - enrollmentID: The user's enrollment UUID.
    ///   - flagID: The feature flag's stable identifier.
    ///   - percentage: The rollout percentage (0–100).
    /// - Returns: `true` if the user's bucket is below the percentage threshold.
    public static func isInRollout(
        enrollmentID: UUID, flagID: String, percentage: Int
    ) -> Bool {
        let userBucket = bucket(enrollmentID: enrollmentID, flagID: flagID)
        return userBucket < percentage
    }
}
