import Foundation
import Testing

@testable import DevToolsKitFeatureFlags

@Suite(.serialized)
@MainActor
struct OverrideExpiryTests {
    private func makeStore() -> FeatureFlagStore {
        let prefix = "test.\(UUID().uuidString)"
        return FeatureFlagStore(
            overrideStore: UserDefaultsOverrideStore(keyPrefix: prefix)
        )
    }

    @Test func overrideWithTTLShowsExpiry() {
        let store = makeStore()

        let flag = FeatureFlag(
            id: "test.ttl", name: "TTL", description: "Test", category: "Test",
            defaultEnabled: false)
        store.register(flag)

        store.setOverride(true, for: "test.ttl", expiresAfter: .seconds(3600))
        let state = store.state(for: "test.ttl")
        #expect(state?.isOverridden == true)
        #expect(state?.overrideExpiresAt != nil)
    }

    @Test func permanentOverrideHasNoExpiry() {
        let store = makeStore()

        let flag = FeatureFlag(
            id: "test.permanent", name: "Perm", description: "Test", category: "Test",
            defaultEnabled: false)
        store.register(flag)

        store.setOverride(true, for: "test.permanent")
        let state = store.state(for: "test.permanent")
        #expect(state?.isOverridden == true)
        #expect(state?.overrideExpiresAt == nil)
    }

    @Test func expiredOverrideFallsBackToDefault() {
        let prefix = "test.\(UUID().uuidString)"
        let overrideStore = UserDefaultsOverrideStore(keyPrefix: prefix)
        let store = FeatureFlagStore(overrideStore: overrideStore)

        let flag = FeatureFlag(
            id: "test.expired", name: "Expired", description: "Test", category: "Test",
            defaultEnabled: false)
        store.register(flag)

        // Set override with already-expired TTL directly in UserDefaults
        let overrideKey = "\(prefix).featureFlag.override.test.expired"
        let existsKey = "\(prefix).featureFlag.override.test.expired.exists"
        let expiryKey = "\(prefix).featureFlag.override.test.expired.expiresAt"
        UserDefaults.standard.set(true, forKey: overrideKey)
        UserDefaults.standard.set(true, forKey: existsKey)
        UserDefaults.standard.set(
            Date().addingTimeInterval(-10).timeIntervalSince1970, forKey: expiryKey)

        let state = store.state(for: "test.expired")
        #expect(state?.isOverridden == false)
        #expect(state?.isEnabled == false)  // falls back to defaultEnabled
    }
}
