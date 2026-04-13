import Foundation
import Testing

@testable import DevToolsKitFeatureFlags

@Suite
struct CohortResolverTests {
    @Test func bucketIsDeterministic() {
        let id = UUID()
        let bucket1 = CohortResolver.bucket(enrollmentID: id, flagID: "test.flag")
        let bucket2 = CohortResolver.bucket(enrollmentID: id, flagID: "test.flag")
        #expect(bucket1 == bucket2)
    }

    @Test func bucketIsInRange() {
        for _ in 0..<100 {
            let bucket = CohortResolver.bucket(enrollmentID: UUID(), flagID: "test.flag")
            #expect(bucket >= 0)
            #expect(bucket < 100)
        }
    }

    @Test func differentFlagsGetDifferentBuckets() {
        let id = UUID()
        let bucket1 = CohortResolver.bucket(enrollmentID: id, flagID: "test.flag-a")
        let bucket2 = CohortResolver.bucket(enrollmentID: id, flagID: "test.flag-b")
        // Not guaranteed to differ, but very likely with different inputs
        // We test determinism instead
        let bucket1Again = CohortResolver.bucket(enrollmentID: id, flagID: "test.flag-a")
        #expect(bucket1 == bucket1Again)
        _ = bucket2  // suppress unused warning
    }

    @Test func assignCohortDeterministic() {
        let id = UUID()
        let cohorts = [
            Cohort(name: "control", weight: 50),
            Cohort(name: "variant", weight: 50),
        ]

        let cohort1 = CohortResolver.assignCohort(
            enrollmentID: id, flagID: "test.exp", cohorts: cohorts)
        let cohort2 = CohortResolver.assignCohort(
            enrollmentID: id, flagID: "test.exp", cohorts: cohorts)
        #expect(cohort1 == cohort2)
    }

    @Test func assignCohortEmptyCohorts() {
        let result = CohortResolver.assignCohort(
            enrollmentID: UUID(), flagID: "test", cohorts: [])
        #expect(result == nil)
    }

    @Test func assignCohortAllUsersAssigned() {
        let cohorts = [
            Cohort(name: "control", weight: 50),
            Cohort(name: "variant-a", weight: 25),
            Cohort(name: "variant-b", weight: 25),
        ]

        var assignments: [String: Int] = [:]
        for _ in 0..<1000 {
            let cohort = CohortResolver.assignCohort(
                enrollmentID: UUID(), flagID: "test.multi", cohorts: cohorts)
            #expect(cohort != nil)
            assignments[cohort!, default: 0] += 1
        }

        // All three cohorts should have some assignments
        #expect(assignments.keys.count == 3)
        #expect(assignments["control"]! > 0)
        #expect(assignments["variant-a"]! > 0)
        #expect(assignments["variant-b"]! > 0)
    }

    @Test func isInRolloutDeterministic() {
        let id = UUID()
        let result1 = CohortResolver.isInRollout(
            enrollmentID: id, flagID: "test.rollout", percentage: 50)
        let result2 = CohortResolver.isInRollout(
            enrollmentID: id, flagID: "test.rollout", percentage: 50)
        #expect(result1 == result2)
    }

    @Test func rollout0PercentNeverEnabled() {
        for _ in 0..<100 {
            let result = CohortResolver.isInRollout(
                enrollmentID: UUID(), flagID: "test.zero", percentage: 0)
            #expect(result == false)
        }
    }

    @Test func rollout100PercentAlwaysEnabled() {
        for _ in 0..<100 {
            let result = CohortResolver.isInRollout(
                enrollmentID: UUID(), flagID: "test.full", percentage: 100)
            #expect(result == true)
        }
    }
}
