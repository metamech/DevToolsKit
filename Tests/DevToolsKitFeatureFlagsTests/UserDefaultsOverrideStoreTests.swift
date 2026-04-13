import Foundation
import Testing
@testable import DevToolsKitFeatureFlags

@Suite("UserDefaultsOverrideStore")
@MainActor
struct UserDefaultsOverrideStoreTests {
    private func makeStore(prefix: String = "test.\(UUID().uuidString)") -> (store: UserDefaultsOverrideStore, prefix: String) {
        (UserDefaultsOverrideStore(keyPrefix: prefix), prefix)
    }

    private func cleanup(prefix: String) {
        let defaults = UserDefaults.standard
        let valueKey = "\(prefix).featureFlag.override.test"
        let existsKey = "\(prefix).featureFlag.override.test.exists"
        let expiryKey = "\(prefix).featureFlag.override.test.expiresAt"

        defaults.removeObject(forKey: valueKey)
        defaults.removeObject(forKey: existsKey)
        defaults.removeObject(forKey: expiryKey)
    }

    // MARK: - Basic Set/Get Tests

    @Test("set and get override")
    func setAndGetOverride() {
        let (store, prefix) = makeStore()
        defer { cleanup(prefix: prefix) }

        store.setOverride(true, for: "test", expiresAfter: nil)
        let override = store.override(for: "test")

        #expect(override != nil)
        #expect(override?.enabled == true)
        #expect(override?.expiresAt == nil)
    }

    @Test("get override for non-existent flag returns nil")
    func getNonExistentReturnsNil() {
        let (store, prefix) = makeStore()
        defer { cleanup(prefix: prefix) }

        let override = store.override(for: "never-set")

        #expect(override == nil)
    }

    @Test("set override false")
    func setOverrideFalse() {
        let (store, prefix) = makeStore()
        defer { cleanup(prefix: prefix) }

        store.setOverride(false, for: "test", expiresAfter: nil)
        let override = store.override(for: "test")

        #expect(override?.enabled == false)
    }

    // MARK: - Clear Tests

    @Test("clear override removes it")
    func clearOverrideRemovesIt() {
        let (store, prefix) = makeStore()
        defer { cleanup(prefix: prefix) }

        store.setOverride(true, for: "test", expiresAfter: nil)
        store.clearOverride(for: "test")
        let override = store.override(for: "test")

        #expect(override == nil)
    }

    @Test("clearAll with multiple flags")
    func clearAllRemovesMultiple() {
        let (store, prefix) = makeStore()
        defer {
            let defaults = UserDefaults.standard
            for flagID in ["test.1", "test.2", "test.3"] {
                defaults.removeObject(forKey: "\(prefix).featureFlag.override.\(flagID)")
                defaults.removeObject(forKey: "\(prefix).featureFlag.override.\(flagID).exists")
                defaults.removeObject(forKey: "\(prefix).featureFlag.override.\(flagID).expiresAt")
            }
        }

        store.setOverride(true, for: "test.1", expiresAfter: nil)
        store.setOverride(true, for: "test.2", expiresAfter: nil)
        store.setOverride(true, for: "test.3", expiresAfter: nil)

        store.clearAll(flagIDs: ["test.1", "test.2", "test.3"])

        #expect(store.override(for: "test.1") == nil)
        #expect(store.override(for: "test.2") == nil)
        #expect(store.override(for: "test.3") == nil)
    }

    @Test("clearAll with non-existent flags is no-op")
    func clearAllNonExistentNoOp() {
        let (store, _) = makeStore()

        // Should not crash or error
        store.clearAll(flagIDs: ["never.set"])

        #expect(true)
    }

    // MARK: - Expiry Tests

    @Test("override with future expiry not expired")
    func overrideWithFutureExpiryNotExpired() {
        let (store, prefix) = makeStore()
        defer { cleanup(prefix: prefix) }

        store.setOverride(true, for: "test", expiresAfter: .seconds(3600))
        let override = store.override(for: "test")

        #expect(override != nil)
        #expect(override?.enabled == true)
        #expect(override?.expiresAt != nil)
    }

    @Test("override with past expiry auto-expires")
    func overrideWithPastExpiryExpires() {
        let (store, prefix) = makeStore()
        defer { cleanup(prefix: prefix) }

        let defaults = UserDefaults.standard
        let valueKey = "\(prefix).featureFlag.override.test"
        let existsKey = "\(prefix).featureFlag.override.test.exists"
        let expiryKey = "\(prefix).featureFlag.override.test.expiresAt"

        // Set override with already-expired timestamp
        defaults.set(true, forKey: valueKey)
        defaults.set(true, forKey: existsKey)
        let pastDate = Date().addingTimeInterval(-10)
        defaults.set(pastDate.timeIntervalSince1970, forKey: expiryKey)

        let override = store.override(for: "test")

        #expect(override == nil)
    }

    @Test("expired override is auto-cleared from UserDefaults")
    func expiredOverrideAutoCleared() {
        let (store, prefix) = makeStore()
        defer { cleanup(prefix: prefix) }

        let defaults = UserDefaults.standard
        let valueKey = "\(prefix).featureFlag.override.test"
        let existsKey = "\(prefix).featureFlag.override.test.exists"
        let expiryKey = "\(prefix).featureFlag.override.test.expiresAt"

        // Set expired override
        defaults.set(true, forKey: valueKey)
        defaults.set(true, forKey: existsKey)
        let pastDate = Date().addingTimeInterval(-10)
        defaults.set(pastDate.timeIntervalSince1970, forKey: expiryKey)

        // Read it (which triggers auto-clear)
        _ = store.override(for: "test")

        // Verify it was cleared
        #expect(defaults.object(forKey: valueKey) == nil)
        #expect(defaults.object(forKey: existsKey) == nil)
        #expect(defaults.object(forKey: expiryKey) == nil)
    }

    @Test("permanent override (no TTL) has no expiresAt")
    func permanentOverrideHasNoExpiry() {
        let (store, prefix) = makeStore()
        defer { cleanup(prefix: prefix) }

        store.setOverride(true, for: "test", expiresAfter: nil)
        let override = store.override(for: "test")

        #expect(override?.expiresAt == nil)
    }

    // MARK: - Key Format Tests

    @Test("key format matches prefix.featureFlag.override.flagID pattern")
    func keyFormatMatches() {
        let prefix = "myapp"
        let store = UserDefaultsOverrideStore(keyPrefix: prefix)
        defer {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: "\(prefix).featureFlag.override.test.flag")
            defaults.removeObject(forKey: "\(prefix).featureFlag.override.test.flag.exists")
            defaults.removeObject(forKey: "\(prefix).featureFlag.override.test.flag.expiresAt")
        }

        store.setOverride(true, for: "test.flag", expiresAfter: nil)

        let defaults = UserDefaults.standard
        let expectedKey = "\(prefix).featureFlag.override.test.flag"
        #expect(defaults.object(forKey: expectedKey) != nil)
    }

    @Test("different prefixes are isolated")
    func prefixIsolation() {
        let (store1, prefix1) = makeStore()
        let (store2, prefix2) = makeStore()
        defer {
            cleanup(prefix: prefix1)
            cleanup(prefix: prefix2)
        }

        store1.setOverride(true, for: "test", expiresAfter: nil)
        store2.setOverride(false, for: "test", expiresAfter: nil)

        let override1 = store1.override(for: "test")
        let override2 = store2.override(for: "test")

        #expect(override1?.enabled == true)
        #expect(override2?.enabled == false)
    }

    @Test("same flag ID in different stores doesn't collide with different prefixes")
    func differPrefixesDontCollide() {
        let prefixA = "appA"
        let prefixB = "appB"
        let storeA = UserDefaultsOverrideStore(keyPrefix: prefixA)
        let storeB = UserDefaultsOverrideStore(keyPrefix: prefixB)

        defer {
            let defaults = UserDefaults.standard
            for prefix in [prefixA, prefixB] {
                defaults.removeObject(forKey: "\(prefix).featureFlag.override.shared")
                defaults.removeObject(forKey: "\(prefix).featureFlag.override.shared.exists")
                defaults.removeObject(forKey: "\(prefix).featureFlag.override.shared.expiresAt")
            }
        }

        storeA.setOverride(true, for: "shared", expiresAfter: nil)
        storeB.setOverride(false, for: "shared", expiresAfter: nil)

        #expect(storeA.override(for: "shared")?.enabled == true)
        #expect(storeB.override(for: "shared")?.enabled == false)
    }

    // MARK: - Edge Cases

    @Test("override persistence round-trip")
    func overridePersistenceRoundTrip() {
        let (store1, prefix) = makeStore()
        defer { cleanup(prefix: prefix) }

        let store2 = UserDefaultsOverrideStore(keyPrefix: prefix)

        store1.setOverride(true, for: "test", expiresAfter: nil)
        let override2 = store2.override(for: "test")

        #expect(override2?.enabled == true)
    }

    @Test("setting override twice overwrites previous")
    func overwritePreviousOverride() {
        let (store, prefix) = makeStore()
        defer { cleanup(prefix: prefix) }

        store.setOverride(true, for: "test", expiresAfter: nil)
        store.setOverride(false, for: "test", expiresAfter: nil)
        let override = store.override(for: "test")

        #expect(override?.enabled == false)
    }

    @Test("clearing non-existent override is no-op")
    func clearNonExistentNoOp() {
        let (store, _) = makeStore()

        // Should not crash
        store.clearOverride(for: "never.set")

        #expect(true)
    }

    @Test("multiple flags in same store are independent")
    func multipleIndependent() {
        let (store, prefix) = makeStore()
        defer {
            let defaults = UserDefaults.standard
            for flagID in ["flag1", "flag2", "flag3"] {
                defaults.removeObject(forKey: "\(prefix).featureFlag.override.\(flagID)")
                defaults.removeObject(forKey: "\(prefix).featureFlag.override.\(flagID).exists")
                defaults.removeObject(forKey: "\(prefix).featureFlag.override.\(flagID).expiresAt")
            }
        }

        store.setOverride(true, for: "flag1", expiresAfter: nil)
        store.setOverride(false, for: "flag2", expiresAfter: nil)
        store.setOverride(true, for: "flag3", expiresAfter: nil)

        #expect(store.override(for: "flag1")?.enabled == true)
        #expect(store.override(for: "flag2")?.enabled == false)
        #expect(store.override(for: "flag3")?.enabled == true)
    }

    @Test("TTL with very small duration expires immediately")
    func verySmallTTLExpires() {
        let (store, prefix) = makeStore()
        defer { cleanup(prefix: prefix) }

        // Use negative duration to ensure it's expired
        let defaults = UserDefaults.standard
        let valueKey = "\(prefix).featureFlag.override.test"
        let existsKey = "\(prefix).featureFlag.override.test.exists"
        let expiryKey = "\(prefix).featureFlag.override.test.expiresAt"

        defaults.set(true, forKey: valueKey)
        defaults.set(true, forKey: existsKey)
        let pastDate = Date().addingTimeInterval(-1)
        defaults.set(pastDate.timeIntervalSince1970, forKey: expiryKey)

        let override = store.override(for: "test")
        #expect(override == nil)
    }
}
