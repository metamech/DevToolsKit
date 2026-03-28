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

    // MARK: - Registration

    @Test func registerFlags() {
        let (manager, _) = makeManager()
        let flag = FeatureFlagDefinition(
            id: "test.flag1", name: "Flag 1", description: "Test", category: "Test")
        manager.registerFlags([flag])

        #expect(manager.flagDefinitions.count == 1)
        #expect(manager.flagOrder == ["test.flag1"])
    }

    @Test func duplicateFlagIgnored() {
        let (manager, _) = makeManager()
        let flag = FeatureFlagDefinition(
            id: "test.flag1", name: "Flag 1", description: "Test", category: "Test")
        manager.registerFlags([flag, flag])

        #expect(manager.flagDefinitions.count == 1)
    }

    @Test func registerSingleFlag() {
        let (manager, _) = makeManager()
        let flag = FeatureFlagDefinition(
            id: "test.single", name: "Single", description: "Test", category: "Test")
        manager.registerFlag(flag)

        #expect(manager.flagDefinitions["test.single"] != nil)
    }

    // MARK: - Default Resolution

    @Test func defaultEnabledFlag() {
        let (manager, _) = makeManager()
        let flag = FeatureFlagDefinition(
            id: "test.default-on", name: "On", description: "Test", category: "Test",
            defaultEnabled: true)
        manager.registerFlag(flag)

        #expect(manager.isEnabled("test.default-on") == true)
    }

    @Test func defaultDisabledFlag() {
        let (manager, _) = makeManager()
        let flag = FeatureFlagDefinition(
            id: "test.default-off", name: "Off", description: "Test", category: "Test",
            defaultEnabled: false)
        manager.registerFlag(flag)

        #expect(manager.isEnabled("test.default-off") == false)
    }

    @Test func unregisteredFlagReturnsFalse() {
        let (manager, _) = makeManager()
        #expect(manager.isEnabled("nonexistent") == false)
    }

    @Test func unregisteredFlagStateIsNil() {
        let (manager, _) = makeManager()
        #expect(manager.flagState(for: "nonexistent") == nil)
    }

    // MARK: - License Gating

    @Test func premiumFlagGatedWhenInactive() {
        let (manager, _) = makeManager()
        let flag = FeatureFlagDefinition(
            id: "test.premium", name: "Premium", description: "Test", category: "Test",
            defaultEnabled: true, requiredTier: .premium)
        manager.registerFlag(flag)

        let state = manager.flagState(for: "test.premium")
        #expect(state?.isEnabled == false)
        #expect(state?.isGated == true)
    }

    @Test func premiumFlagEnabledWhenActive() async throws {
        let backend = MockBackend()
        let (manager, _) = makeManager(backend: backend)
        try await manager.activate(with: .licenseKey("test-key"))

        let flag = FeatureFlagDefinition(
            id: "test.premium", name: "Premium", description: "Test", category: "Test",
            defaultEnabled: true, requiredTier: .premium)
        manager.registerFlag(flag)

        let state = manager.flagState(for: "test.premium")
        #expect(state?.isEnabled == true)
        #expect(state?.isGated == false)
    }

    @Test func freeTierAlwaysSatisfied() {
        let (manager, _) = makeManager()
        let flag = FeatureFlagDefinition(
            id: "test.free", name: "Free", description: "Test", category: "Test",
            defaultEnabled: true, requiredTier: .free)
        manager.registerFlag(flag)

        #expect(manager.isEnabled("test.free") == true)
    }

    // MARK: - Overrides

    @Test func overrideEnablesDisabledFlag() {
        let (manager, _) = makeManager()
        let flag = FeatureFlagDefinition(
            id: "test.disabled", name: "Disabled", description: "Test", category: "Test",
            defaultEnabled: false)
        manager.registerFlag(flag)

        manager.setOverride(true, for: "test.disabled")
        let state = manager.flagState(for: "test.disabled")
        #expect(state?.isEnabled == true)
        #expect(state?.isOverridden == true)
    }

    @Test func overrideDisablesEnabledFlag() {
        let (manager, _) = makeManager()
        let flag = FeatureFlagDefinition(
            id: "test.enabled", name: "Enabled", description: "Test", category: "Test",
            defaultEnabled: true)
        manager.registerFlag(flag)

        manager.setOverride(false, for: "test.enabled")
        #expect(manager.isEnabled("test.enabled") == false)
    }

    @Test func clearOverride() {
        let (manager, _) = makeManager()
        let flag = FeatureFlagDefinition(
            id: "test.flag", name: "Flag", description: "Test", category: "Test",
            defaultEnabled: false)
        manager.registerFlag(flag)

        manager.setOverride(true, for: "test.flag")
        #expect(manager.isEnabled("test.flag") == true)

        manager.clearOverride(for: "test.flag")
        #expect(manager.isEnabled("test.flag") == false)
    }

    @Test func clearAllOverrides() {
        let (manager, _) = makeManager()
        let flag1 = FeatureFlagDefinition(
            id: "test.f1", name: "F1", description: "Test", category: "Test", defaultEnabled: false)
        let flag2 = FeatureFlagDefinition(
            id: "test.f2", name: "F2", description: "Test", category: "Test", defaultEnabled: false)
        manager.registerFlags([flag1, flag2])

        manager.setOverride(true, for: "test.f1")
        manager.setOverride(true, for: "test.f2")
        manager.clearAllOverrides()

        #expect(manager.isEnabled("test.f1") == false)
        #expect(manager.isEnabled("test.f2") == false)
    }

    @Test func overrideBypassesLicenseGating() {
        let (manager, _) = makeManager()
        let flag = FeatureFlagDefinition(
            id: "test.gated", name: "Gated", description: "Test", category: "Test",
            defaultEnabled: true, requiredTier: .premium)
        manager.registerFlag(flag)

        manager.setOverride(true, for: "test.gated")
        let state = manager.flagState(for: "test.gated")
        #expect(state?.isEnabled == true)
        #expect(state?.isOverridden == true)
        #expect(state?.isGated == false)
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

    // MARK: - State Version

    @Test func stateVersionIncrements() {
        let (manager, _) = makeManager()
        let flag = FeatureFlagDefinition(
            id: "test.flag", name: "Flag", description: "Test", category: "Test")
        manager.registerFlag(flag)

        let v0 = manager.stateVersion
        manager.setOverride(true, for: "test.flag")
        #expect(manager.stateVersion > v0)
    }

    // MARK: - All Flag States

    @Test func allFlagStatesReturnsInOrder() {
        let (manager, _) = makeManager()
        let f1 = FeatureFlagDefinition(
            id: "test.first", name: "First", description: "Test", category: "A")
        let f2 = FeatureFlagDefinition(
            id: "test.second", name: "Second", description: "Test", category: "B")
        manager.registerFlags([f1, f2])

        let states = manager.allFlagStates
        #expect(states.count == 2)
        #expect(states[0].definition.id == "test.first")
        #expect(states[1].definition.id == "test.second")
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

    @Test func trialGrantsPremiumTier() {
        let (manager, _) = makeManager()
        let flag = FeatureFlagDefinition(
            id: "test.premium", name: "Premium", description: "Test", category: "Test",
            defaultEnabled: true, requiredTier: .premium)
        manager.registerFlag(flag)
        manager.configureTrial(TrialConfiguration(durationDays: 14))
        manager.trial?.startTrialIfNeeded()

        #expect(manager.isEnabled("test.premium") == true)
    }

    @Test func expiredStatusDoesNotSatisfyPremium() {
        let backend = MockBackend()
        backend.status = .expired
        let (manager, _) = makeManager(backend: backend)
        let flag = FeatureFlagDefinition(
            id: "test.premium", name: "Premium", description: "Test", category: "Test",
            defaultEnabled: true, requiredTier: .premium)
        manager.registerFlag(flag)

        #expect(manager.isEnabled("test.premium") == false)
    }
}
