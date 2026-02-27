import Foundation
import Testing

@testable import DevToolsKitLicensing

@Suite(.serialized)
@MainActor
struct RolloutTests {
    @Test func rolloutPercentageClamped() {
        let over = RolloutDefinition(percentage: 150)
        #expect(over.percentage == 100)

        let under = RolloutDefinition(percentage: -10)
        #expect(under.percentage == 0)
    }

    @Test func rolloutFlagResolution() {
        let prefix = "test.\(UUID().uuidString)"
        let backend = MockBackend()
        let manager = LicensingManager(keyPrefix: prefix, backend: backend)

        // 100% rollout with no targeting
        let flag = FeatureFlagDefinition(
            id: "test.full-rollout", name: "Full", description: "Test", category: "Test",
            defaultEnabled: false, rollout: RolloutDefinition(percentage: 100))
        manager.registerFlag(flag)

        #expect(manager.isEnabled("test.full-rollout") == true)
    }

    @Test func zeroRolloutUsesDefault() {
        let prefix = "test.\(UUID().uuidString)"
        let backend = MockBackend()
        let manager = LicensingManager(keyPrefix: prefix, backend: backend)

        let flag = FeatureFlagDefinition(
            id: "test.zero-rollout", name: "Zero", description: "Test", category: "Test",
            defaultEnabled: true, rollout: RolloutDefinition(percentage: 0))
        manager.registerFlag(flag)

        // With 0% rollout, eligible users get false from rollout, so result is false
        #expect(manager.isEnabled("test.zero-rollout") == false)
    }

    @Test func rolloutDistribution() {
        // Statistical test: 50% rollout should give roughly half enabled
        var enabledCount = 0
        let trials = 1000
        for _ in 0..<trials {
            let prefix = "test.\(UUID().uuidString)"
            let backend = MockBackend()
            let manager = LicensingManager(keyPrefix: prefix, backend: backend)

            let flag = FeatureFlagDefinition(
                id: "test.half", name: "Half", description: "Test", category: "Test",
                defaultEnabled: false, rollout: RolloutDefinition(percentage: 50))
            manager.registerFlag(flag)

            if manager.isEnabled("test.half") { enabledCount += 1 }
        }

        // Should be roughly 500, allow wide margin
        #expect(enabledCount > 300)
        #expect(enabledCount < 700)
    }
}
