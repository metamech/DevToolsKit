import Foundation
import Testing

@testable import DevToolsKitLicensing

@Suite(.serialized)
@MainActor
struct CustomEntitlementTests {
    @Test func customTierNotSatisfiedWithoutEntitlement() {
        let backend = MockBackend()
        let prefix = "test.\(UUID().uuidString)"
        let manager = LicensingManager(keyPrefix: prefix, backend: backend)

        #expect(manager.isTierSatisfied(.custom("enterprise")) == false)
    }

    @Test func customTierSatisfiedWithEntitlement() {
        let backend = MockBackend()
        backend.activeEntitlements = ["enterprise"]
        let prefix = "test.\(UUID().uuidString)"
        let manager = LicensingManager(keyPrefix: prefix, backend: backend)

        #expect(manager.isTierSatisfied(.custom("enterprise")) == true)
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
}
