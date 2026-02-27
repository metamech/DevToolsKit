import Foundation
import Testing

@testable import DevToolsKitLicensing

@Suite(.serialized)
@MainActor
struct CustomEntitlementTests {
    @Test func customTierGatedWithoutEntitlement() {
        let backend = MockBackend()
        let prefix = "test.\(UUID().uuidString)"
        let manager = LicensingManager(keyPrefix: prefix, backend: backend)

        let flag = FeatureFlagDefinition(
            id: "test.enterprise", name: "Enterprise", description: "Test", category: "Premium",
            defaultEnabled: true, requiredTier: .custom("enterprise"))
        manager.registerFlag(flag)

        let state = manager.flagState(for: "test.enterprise")
        #expect(state?.isEnabled == false)
        #expect(state?.isGated == true)
    }

    @Test func customTierEnabledWithEntitlement() {
        let backend = MockBackend()
        backend.activeEntitlements = ["enterprise"]
        let prefix = "test.\(UUID().uuidString)"
        let manager = LicensingManager(keyPrefix: prefix, backend: backend)

        let flag = FeatureFlagDefinition(
            id: "test.enterprise", name: "Enterprise", description: "Test", category: "Premium",
            defaultEnabled: true, requiredTier: .custom("enterprise"))
        manager.registerFlag(flag)

        let state = manager.flagState(for: "test.enterprise")
        #expect(state?.isEnabled == true)
        #expect(state?.isGated == false)
    }

    @Test func hasEntitlementDelegates() {
        let backend = MockBackend()
        backend.activeEntitlements = ["feature-a", "feature-b"]
        let prefix = "test.\(UUID().uuidString)"
        let manager = LicensingManager(keyPrefix: prefix, backend: backend)

        #expect(manager.hasEntitlement("feature-a") == true)
        #expect(manager.hasEntitlement("feature-b") == true)
        #expect(manager.hasEntitlement("feature-c") == false)
    }

    @Test func overrideBypassesCustomEntitlement() {
        let backend = MockBackend()
        let prefix = "test.\(UUID().uuidString)"
        let manager = LicensingManager(keyPrefix: prefix, backend: backend)

        let flag = FeatureFlagDefinition(
            id: "test.custom-override", name: "Custom", description: "Test", category: "Premium",
            defaultEnabled: true, requiredTier: .custom("special"))
        manager.registerFlag(flag)

        #expect(manager.isEnabled("test.custom-override") == false)  // gated

        manager.setOverride(true, for: "test.custom-override")
        #expect(manager.isEnabled("test.custom-override") == true)  // override bypasses gate
    }
}
