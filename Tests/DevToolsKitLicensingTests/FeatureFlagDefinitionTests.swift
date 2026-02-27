import Foundation
import Testing

@testable import DevToolsKitLicensing

@Suite
struct FeatureFlagDefinitionTests {
    @Test func defaultValues() {
        let flag = FeatureFlagDefinition(
            id: "test.flag", name: "Test", description: "Desc", category: "Cat")

        #expect(flag.defaultEnabled == false)
        #expect(flag.requiredTier == .free)
        #expect(flag.rollout == nil)
        #expect(flag.experiment == nil)
    }

    @Test func hashableConformance() {
        let flag1 = FeatureFlagDefinition(
            id: "test.a", name: "A", description: "Desc", category: "Cat")
        let flag2 = FeatureFlagDefinition(
            id: "test.a", name: "A", description: "Desc", category: "Cat")
        let flag3 = FeatureFlagDefinition(
            id: "test.b", name: "B", description: "Desc", category: "Cat")

        #expect(flag1 == flag2)
        #expect(flag1 != flag3)
    }

    @Test func identifiableConformance() {
        let flag = FeatureFlagDefinition(
            id: "test.identifiable", name: "ID", description: "Desc", category: "Cat")
        #expect(flag.id == "test.identifiable")
    }

    @Test func withRollout() {
        let rollout = RolloutDefinition(percentage: 50)
        let flag = FeatureFlagDefinition(
            id: "test.rollout", name: "Rollout", description: "Desc", category: "Cat",
            rollout: rollout)

        #expect(flag.rollout?.percentage == 50)
    }

    @Test func withExperiment() {
        let experiment = CohortDefinition(cohorts: [
            Cohort(name: "control", weight: 50),
            Cohort(name: "variant", weight: 50),
        ])
        let flag = FeatureFlagDefinition(
            id: "test.exp", name: "Exp", description: "Desc", category: "Cat",
            experiment: experiment)

        #expect(flag.experiment?.cohorts.count == 2)
    }

    @Test func licenseTierEquality() {
        #expect(LicenseTier.free == LicenseTier.free)
        #expect(LicenseTier.premium == LicenseTier.premium)
        #expect(LicenseTier.custom("a") == LicenseTier.custom("a"))
        #expect(LicenseTier.custom("a") != LicenseTier.custom("b"))
        #expect(LicenseTier.free != LicenseTier.premium)
    }
}
