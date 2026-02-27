import Foundation
import Testing

@testable import DevToolsKitLicensing

@Suite(.serialized)
@MainActor
struct OverrideExpiryTests {
    @Test func overrideWithTTLShowsExpiry() {
        let prefix = "test.\(UUID().uuidString)"
        let backend = MockBackend()
        let manager = LicensingManager(keyPrefix: prefix, backend: backend)

        let flag = FeatureFlagDefinition(
            id: "test.ttl", name: "TTL", description: "Test", category: "Test",
            defaultEnabled: false)
        manager.registerFlag(flag)

        manager.setOverride(true, for: "test.ttl", expiresAfter: .seconds(3600))
        let state = manager.flagState(for: "test.ttl")
        #expect(state?.isOverridden == true)
        #expect(state?.overrideExpiresAt != nil)
    }

    @Test func permanentOverrideHasNoExpiry() {
        let prefix = "test.\(UUID().uuidString)"
        let backend = MockBackend()
        let manager = LicensingManager(keyPrefix: prefix, backend: backend)

        let flag = FeatureFlagDefinition(
            id: "test.permanent", name: "Perm", description: "Test", category: "Test",
            defaultEnabled: false)
        manager.registerFlag(flag)

        manager.setOverride(true, for: "test.permanent")
        let state = manager.flagState(for: "test.permanent")
        #expect(state?.isOverridden == true)
        #expect(state?.overrideExpiresAt == nil)
    }

    @Test func expiredOverrideFallsBackToDefault() {
        let prefix = "test.\(UUID().uuidString)"
        let backend = MockBackend()
        let manager = LicensingManager(keyPrefix: prefix, backend: backend)

        let flag = FeatureFlagDefinition(
            id: "test.expired", name: "Expired", description: "Test", category: "Test",
            defaultEnabled: false)
        manager.registerFlag(flag)

        // Set override with already-expired TTL
        let overrideKey = "\(prefix).featureFlag.override.test.expired"
        let existsKey = "\(prefix).featureFlag.override.test.expired.exists"
        let expiryKey = "\(prefix).featureFlag.override.test.expired.expiresAt"
        UserDefaults.standard.set(true, forKey: overrideKey)
        UserDefaults.standard.set(true, forKey: existsKey)
        UserDefaults.standard.set(
            Date().addingTimeInterval(-10).timeIntervalSince1970, forKey: expiryKey)

        let state = manager.flagState(for: "test.expired")
        #expect(state?.isOverridden == false)
        #expect(state?.isEnabled == false)  // falls back to defaultEnabled
    }
}
