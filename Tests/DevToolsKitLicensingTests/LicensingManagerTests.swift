import Foundation
import Testing

@testable import DevToolsKitLicensing

@Suite(.serialized)
@MainActor
struct LicensingManagerTests {
    private func makeManager(
        backend: MockBackend = MockBackend()
    ) -> (LicensingManager, MockBackend) {
        let prefix = "test.\(UUID().uuidString)"
        let manager = LicensingManager(keyPrefix: prefix, backend: backend)
        return (manager, backend)
    }

    // MARK: - License Actions

    @Test func activateDelegatesToBackend() async throws {
        let backend = MockBackend()
        let (manager, _) = makeManager(backend: backend)

        try await manager.activate(with: .licenseKey("key-123"))
        #expect(backend.activateCallCount == 1)
        #expect(manager.licenseStatus == .active)
    }

    @Test func validateDelegatesToBackend() async throws {
        let backend = MockBackend()
        let (manager, _) = makeManager(backend: backend)

        try await manager.validate()
        #expect(backend.validateCallCount == 1)
    }

    @Test func deactivateDelegatesToBackend() async throws {
        let backend = MockBackend()
        let (manager, _) = makeManager(backend: backend)

        try await manager.deactivate()
        #expect(backend.deactivateCallCount == 1)
        #expect(manager.licenseStatus == .inactive)
    }

    // MARK: - Entitlements

    @Test func hasEntitlementDelegatesToBackend() {
        let backend = MockBackend()
        backend.activeEntitlements = ["enterprise"]
        let (manager, _) = makeManager(backend: backend)

        #expect(manager.hasEntitlement("enterprise") == true)
        #expect(manager.hasEntitlement("nonexistent") == false)
    }

    // MARK: - Tier Satisfaction

    @Test func freeTierAlwaysSatisfied() {
        let (manager, _) = makeManager()
        #expect(manager.isTierSatisfied(.free) == true)
    }

    @Test func premiumTierNotSatisfiedWhenInactive() {
        let (manager, _) = makeManager()
        #expect(manager.isTierSatisfied(.premium) == false)
    }

    @Test func premiumTierSatisfiedWhenActive() async throws {
        let backend = MockBackend()
        let (manager, _) = makeManager(backend: backend)
        try await manager.activate(with: .licenseKey("test-key"))
        #expect(manager.isTierSatisfied(.premium) == true)
    }

    @Test func customTierNotSatisfiedWithoutEntitlement() {
        let (manager, _) = makeManager()
        #expect(manager.isTierSatisfied(.custom("enterprise")) == false)
    }

    @Test func customTierSatisfiedWithEntitlement() {
        let backend = MockBackend()
        backend.activeEntitlements = ["enterprise"]
        let (manager, _) = makeManager(backend: backend)
        #expect(manager.isTierSatisfied(.custom("enterprise")) == true)
    }

    @Test func trialGrantsPremiumTier() {
        let (manager, _) = makeManager()
        manager.configureTrial(TrialConfiguration(durationDays: 14))
        manager.trial?.startTrialIfNeeded()
        #expect(manager.isTierSatisfied(.premium) == true)
    }

    // MARK: - Effective License State

    @Test func effectiveStateLicensed() {
        let backend = MockBackend()
        backend.status = .active
        backend.activeEntitlements = ["premium"]
        let (manager, _) = makeManager(backend: backend)
        #expect(manager.effectiveState == .licensed)
    }

    @Test func effectiveStateTrial() {
        let (manager, _) = makeManager()
        manager.configureTrial(TrialConfiguration(durationDays: 14))
        manager.trial?.startTrialIfNeeded()
        #expect(manager.effectiveState == .trial(daysRemaining: manager.trial!.daysRemaining))
    }

    @Test func effectiveStateTrialExpired() {
        let (manager, _) = makeManager()
        manager.configureTrial(TrialConfiguration(durationDays: 0))
        manager.trial?.startTrialIfNeeded()
        manager.trial?.refresh()
        #expect(manager.effectiveState == .trialExpired)
    }

    @Test func effectiveStateExpired() {
        let (manager, _) = makeManager()
        manager.configureTrial(TrialConfiguration(durationDays: 0))
        manager.trial?.startTrialIfNeeded()
        manager.trial?.wasEverLicensed = true
        manager.trial?.refresh()
        #expect(manager.effectiveState == .expired)
    }

    @Test func effectiveStateUnlicensed() {
        let (manager, _) = makeManager()
        #expect(manager.effectiveState == .unlicensed)
    }

    @Test func expiredStatusDoesNotSatisfyPremium() {
        let backend = MockBackend()
        backend.status = .expired
        let (manager, _) = makeManager(backend: backend)
        #expect(manager.isTierSatisfied(.premium) == false)
    }
}
