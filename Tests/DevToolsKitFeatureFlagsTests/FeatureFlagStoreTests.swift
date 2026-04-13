import Foundation
import Testing
@testable import DevToolsKitFeatureFlags

// MARK: - Test Helpers

/// In-memory override store for testing without UserDefaults side effects.
@MainActor
final class MockOverrideStore: OverrideStore {
    var overrides: [String: OverrideValue] = [:]

    nonisolated init() {}

    func override(for flagID: String) -> OverrideValue? {
        overrides[flagID]
    }

    func setOverride(_ enabled: Bool, for flagID: String, expiresAfter ttl: Duration?) {
        let expiresAt = ttl.map { Date().addingTimeInterval(Double($0.components.seconds)) }
        overrides[flagID] = OverrideValue(enabled: enabled, expiresAt: expiresAt)
    }

    func clearOverride(for flagID: String) {
        overrides.removeValue(forKey: flagID)
    }

    func clearAll(flagIDs: [String]) {
        for flagID in flagIDs {
            overrides.removeValue(forKey: flagID)
        }
    }
}

/// Mock resolution strategy for testing strategy chains.
@MainActor
final class MockStrategy: FlagResolutionStrategy, @unchecked Sendable {
    let name: String
    var results: [String: Bool] = [:]
    var details: [String: String] = [:]

    nonisolated init(name: String) {
        self.name = name
    }

    func resolve(_ flag: FeatureFlag) -> Bool? {
        results[flag.id]
    }

    func detail(for flag: FeatureFlag) -> String? {
        details[flag.id]
    }
}

// MARK: - Test Suite

@Suite("FeatureFlagStore")
@MainActor
struct FeatureFlagStoreTests {
    // MARK: - Registration Tests

    @Test("Registration: registers flags with unique IDs")
    func registersFlags() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flag1 = FeatureFlag(id: "test.flag1", name: "Flag 1", description: "Test flag 1")
        let flag2 = FeatureFlag(id: "test.flag2", name: "Flag 2", description: "Test flag 2")

        store.register([flag1, flag2])

        #expect(store.flagDefinitions["test.flag1"] == flag1)
        #expect(store.flagDefinitions["test.flag2"] == flag2)
        #expect(store.flagOrder == ["test.flag1", "test.flag2"])
    }

    @Test("Registration: duplicate IDs silently ignored, first registration wins")
    func duplicateFlagsIgnored() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flag1 = FeatureFlag(
            id: "test.dup", name: "Original", description: "Original",
            defaultEnabled: false)
        let flag2 = FeatureFlag(
            id: "test.dup", name: "Duplicate", description: "Duplicate",
            defaultEnabled: true)

        store.register(flag1)
        store.register(flag2)

        #expect(store.flagDefinitions["test.dup"] == flag1)
        #expect(store.flagDefinitions["test.dup"]!.name == "Original")
        #expect(store.flagOrder == ["test.dup"])
    }

    @Test("Registration: flagOrder preserved across multiple registrations")
    func flagOrderPreserved() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flags1 = [
            FeatureFlag(id: "a", name: "A", description: ""),
            FeatureFlag(id: "b", name: "B", description: ""),
        ]
        let flags2 = [
            FeatureFlag(id: "c", name: "C", description: ""),
        ]

        store.register(flags1)
        store.register(flags2)

        #expect(store.flagOrder == ["a", "b", "c"])
    }

    // MARK: - Default Resolution Tests

    @Test("Default resolution: unregistered flag returns nil")
    func unregisteredFlagReturnsNil() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())

        let state = store.state(for: "unknown.flag")

        #expect(state == nil)
    }

    @Test("Default resolution: registered flag returns defaultEnabled value")
    func registeredFlagReturnsDefault() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flag = FeatureFlag(
            id: "test.default", name: "Default", description: "",
            defaultEnabled: true)

        store.register(flag)
        let state = store.state(for: "test.default")

        #expect(state?.isEnabled == true)
        if case .defaultValue = state?.resolution {
            #expect(true)
        } else {
            #expect(false, "expected .defaultValue resolution")
        }
    }

    @Test("Default resolution: isEnabled returns false for unregistered flag")
    func isEnabledReturnsFalseForUnregistered() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())

        let result = store.isEnabled("unknown.flag")

        #expect(result == false)
    }

    // MARK: - Override Tests

    @Test("Override: setOverride overrides default value")
    func setOverrideOverridesDefault() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flag = FeatureFlag(
            id: "test.override", name: "Override", description: "",
            defaultEnabled: false)

        store.register(flag)
        store.setOverride(true, for: "test.override")
        let state = store.state(for: "test.override")

        #expect(state?.isEnabled == true)
        #expect(state?.isOverridden == true)
    }

    @Test("Override: clearOverride restores default value")
    func clearOverrideRestoresDefault() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flag = FeatureFlag(
            id: "test.clear", name: "Clear", description: "",
            defaultEnabled: false)

        store.register(flag)
        store.setOverride(true, for: "test.clear")
        store.clearOverride(for: "test.clear")
        let state = store.state(for: "test.clear")

        #expect(state?.isEnabled == false)
        #expect(state?.isOverridden == false)
    }

    @Test("Override: clearAllOverrides clears all overrides")
    func clearAllOverridesRemovesAll() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flags = [
            FeatureFlag(id: "test.1", name: "1", description: "", defaultEnabled: false),
            FeatureFlag(id: "test.2", name: "2", description: "", defaultEnabled: false),
            FeatureFlag(id: "test.3", name: "3", description: "", defaultEnabled: false),
        ]

        store.register(flags)
        store.setOverride(true, for: "test.1")
        store.setOverride(true, for: "test.2")
        store.setOverride(true, for: "test.3")
        store.clearAllOverrides()

        #expect(store.state(for: "test.1")?.isOverridden == false)
        #expect(store.state(for: "test.2")?.isOverridden == false)
        #expect(store.state(for: "test.3")?.isOverridden == false)
    }

    @Test("Override: with TTL (non-expired) shows expiry date")
    func overrideWithTTLShowsExpiry() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flag = FeatureFlag(id: "test.ttl", name: "TTL", description: "")

        store.register(flag)
        store.setOverride(true, for: "test.ttl", expiresAfter: .seconds(3600))
        let state = store.state(for: "test.ttl")

        #expect(state?.overrideExpiresAt != nil)
        #expect(state?.isOverridden == true)
    }

    // MARK: - Strategy Tests

    @Test("Strategy: single strategy returns non-nil, overrides default")
    func strategyReturnsNonNilOverridesDefault() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flag = FeatureFlag(id: "test.strat", name: "Strategy", description: "", defaultEnabled: false)

        let strategy = MockStrategy(name: "test-strategy")
        strategy.results["test.strat"] = true

        store.register(flag)
        store.addStrategy(strategy)
        let state = store.state(for: "test.strat")

        #expect(state?.isEnabled == true)
        if case .strategy(name: let name, detail: _) = state?.resolution {
            #expect(name == "test-strategy")
        } else {
            #expect(false, "expected .strategy resolution")
        }
    }

    @Test("Strategy: returns nil for unknown flag, defers to default")
    func strategyDeferringToDefault() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flag = FeatureFlag(id: "test.defer", name: "Defer", description: "", defaultEnabled: true)

        let strategy = MockStrategy(name: "selective")
        // Don't set a result for this flag

        store.register(flag)
        store.addStrategy(strategy)
        let state = store.state(for: "test.defer")

        #expect(state?.isEnabled == true)
        if case .defaultValue = state?.resolution {
            #expect(true)
        } else {
            #expect(false, "expected .defaultValue resolution")
        }
    }

    @Test("Strategy: can return false, blocks even when default is true")
    func strategyReturningFalseBlocksDefault() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flag = FeatureFlag(id: "test.block", name: "Block", description: "", defaultEnabled: true)

        let strategy = MockStrategy(name: "blocker")
        strategy.results["test.block"] = false

        store.register(flag)
        store.addStrategy(strategy)
        let state = store.state(for: "test.block")

        #expect(state?.isEnabled == false)
    }

    @Test("Strategy: first non-nil wins when multiple strategies added")
    func strategyOrderingFirstNonNilWins() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flag = FeatureFlag(id: "test.multi", name: "Multi", description: "", defaultEnabled: false)

        let strategy1 = MockStrategy(name: "first")
        let strategy2 = MockStrategy(name: "second")

        // First strategy returns nil for this flag
        // Second strategy returns true
        strategy2.results["test.multi"] = true

        store.register(flag)
        store.addStrategy(strategy1)
        store.addStrategy(strategy2)
        let state = store.state(for: "test.multi")

        #expect(state?.isEnabled == true)
        if case .strategy(name: let name, detail: _) = state?.resolution {
            #expect(name == "second")
        } else {
            #expect(false, "expected second strategy to win")
        }
    }

    @Test("Strategy: detail string appears in resolution")
    func strategyDetailAppears() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flag = FeatureFlag(id: "test.detail", name: "Detail", description: "")

        let strategy = MockStrategy(name: "detailed")
        strategy.results["test.detail"] = true
        strategy.details["test.detail"] = "requires premium license"

        store.register(flag)
        store.addStrategy(strategy)
        let state = store.state(for: "test.detail")

        if case .strategy(name: _, detail: let detail) = state?.resolution {
            #expect(detail == "requires premium license")
        } else {
            #expect(false, "expected detail in resolution")
        }
    }

    // MARK: - Override vs Strategy Tests

    @Test("Resolution order: override beats strategy")
    func overrideBeatStrategy() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flag = FeatureFlag(id: "test.precedence", name: "Precedence", description: "", defaultEnabled: false)

        let strategy = MockStrategy(name: "strategy")
        strategy.results["test.precedence"] = false

        store.register(flag)
        store.addStrategy(strategy)
        store.setOverride(true, for: "test.precedence")
        let state = store.state(for: "test.precedence")

        #expect(state?.isEnabled == true)
        #expect(state?.isOverridden == true)
    }

    // MARK: - Invalidation Tests

    @Test("Invalidation: invalidate increments stateVersion")
    func invalidateIncrementsVersion() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let initial = store.stateVersion

        store.invalidate()

        #expect(store.stateVersion == initial + 1)
    }

    @Test("Invalidation: setOverride increments stateVersion")
    func setOverrideIncrementsVersion() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flag = FeatureFlag(id: "test.vers", name: "Version", description: "")

        store.register(flag)
        let initial = store.stateVersion
        store.setOverride(true, for: "test.vers")

        #expect(store.stateVersion == initial + 1)
    }

    @Test("Invalidation: clearOverride increments stateVersion")
    func clearOverrideIncrementsVersion() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flag = FeatureFlag(id: "test.clear-vers", name: "Clear Version", description: "")

        store.register(flag)
        store.setOverride(true, for: "test.clear-vers")
        let initial = store.stateVersion
        store.clearOverride(for: "test.clear-vers")

        #expect(store.stateVersion == initial + 1)
    }

    @Test("Invalidation: clearAllOverrides increments stateVersion")
    func clearAllOverridesIncrementsVersion() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flags = [
            FeatureFlag(id: "test.a", name: "A", description: ""),
            FeatureFlag(id: "test.b", name: "B", description: ""),
        ]

        store.register(flags)
        store.setOverride(true, for: "test.a")
        let initial = store.stateVersion
        store.clearAllOverrides()

        #expect(store.stateVersion == initial + 1)
    }

    @Test("Invalidation: addStrategy increments stateVersion")
    func addStrategyIncrementsVersion() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let initial = store.stateVersion

        store.addStrategy(MockStrategy(name: "test"))

        #expect(store.stateVersion == initial + 1)
    }

    @Test("Invalidation: removeStrategy increments stateVersion")
    func removeStrategyIncrementsVersion() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())

        store.addStrategy(MockStrategy(name: "to-remove"))
        let initial = store.stateVersion
        store.removeStrategy(named: "to-remove")

        #expect(store.stateVersion == initial + 1)
    }

    // MARK: - allStates Tests

    @Test("allStates: returns all states in registration order")
    func allStatesPreservesOrder() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flags = [
            FeatureFlag(id: "z", name: "Z", description: ""),
            FeatureFlag(id: "a", name: "A", description: ""),
            FeatureFlag(id: "m", name: "M", description: ""),
        ]

        store.register(flags)
        let allStates = store.allStates

        #expect(allStates.count == 3)
        #expect(allStates[0].flag.id == "z")
        #expect(allStates[1].flag.id == "a")
        #expect(allStates[2].flag.id == "m")
    }

    @Test("allStates: reflects current overrides and strategies")
    func allStatesReflectsCurrent() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flags = [
            FeatureFlag(id: "test.1", name: "1", description: "", defaultEnabled: false),
            FeatureFlag(id: "test.2", name: "2", description: "", defaultEnabled: true),
        ]

        store.register(flags)
        store.setOverride(true, for: "test.1")

        let allStates = store.allStates
        #expect(allStates[0].isEnabled == true)
        #expect(allStates[0].isOverridden == true)
        #expect(allStates[1].isEnabled == true)
        #expect(allStates[1].isOverridden == false)
    }

    // MARK: - Strategy Removal Tests

    @Test("removeStrategy: removes strategy by name")
    func removeStrategyByName() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flag = FeatureFlag(id: "test.remove", name: "Remove", description: "", defaultEnabled: false)

        let strategy = MockStrategy(name: "removable")
        strategy.results["test.remove"] = true

        store.register(flag)
        store.addStrategy(strategy)
        let beforeRemoval = store.state(for: "test.remove")
        #expect(beforeRemoval?.isEnabled == true)

        store.removeStrategy(named: "removable")
        let afterRemoval = store.state(for: "test.remove")
        #expect(afterRemoval?.isEnabled == false)
    }

    @Test("removeStrategy: non-existent strategy is no-op")
    func removeStrategyNonExistent() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())

        let version = store.stateVersion
        store.removeStrategy(named: "does-not-exist")
        // Should still increment version
        #expect(store.stateVersion == version + 1)
    }

    // MARK: - FlagResolution Type Tests

    @Test("FlagResolution: .override case tracks expiry")
    func overrideResolutionTracksExpiry() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flag = FeatureFlag(id: "test.exp", name: "Expiry", description: "")

        store.register(flag)
        store.setOverride(true, for: "test.exp", expiresAfter: .seconds(3600))
        let state = store.state(for: "test.exp")

        #expect(state?.overrideExpiresAt != nil)
        #expect(state?.isOverridden == true)
    }

    @Test("FlagResolution: .strategy case reports name and detail")
    func strategyResolutionReportsDetails() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flag = FeatureFlag(id: "test.strat-detail", name: "Detail", description: "")

        let strategy = MockStrategy(name: "licensing")
        strategy.results["test.strat-detail"] = true
        strategy.details["test.strat-detail"] = "tier: premium"

        store.register(flag)
        store.addStrategy(strategy)
        let state = store.state(for: "test.strat-detail")

        if case .strategy(name: let name, detail: let detail) = state?.resolution {
            #expect(name == "licensing")
            #expect(detail == "tier: premium")
        } else {
            #expect(false, "expected strategy resolution")
        }
    }

    @Test("FlagResolution: .defaultValue case when neither override nor strategy applies")
    func defaultValueResolution() {
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flag = FeatureFlag(id: "test.default-res", name: "Default", description: "", defaultEnabled: true)

        store.register(flag)
        let state = store.state(for: "test.default-res")

        if case .defaultValue = state?.resolution {
            #expect(true)
        } else {
            #expect(false, "expected .defaultValue resolution")
        }
    }

    // MARK: - Metrics Handler Tests

    @Test("Metrics: isEnabled calls recordCheck on metricsHandler")
    func metricsHandlerCalled() {
        let mockMetrics = MockMetricsHandler()
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flag = FeatureFlag(id: "test.metrics", name: "Metrics", description: "")

        store.register(flag)
        store.metricsHandler = mockMetrics

        let result = store.isEnabled("test.metrics")

        #expect(mockMetrics.recordedChecks.count == 1)
        #expect(mockMetrics.recordedChecks[0].flagID == "test.metrics")
        #expect(mockMetrics.recordedChecks[0].result == result)
    }

    @Test("Metrics: setOverride calls recordOverride")
    func metricsOverrideRecorded() {
        let mockMetrics = MockMetricsHandler()
        let store = FeatureFlagStore(overrideStore: MockOverrideStore())
        let flag = FeatureFlag(id: "test.metrics-override", name: "Override", description: "")

        store.register(flag)
        store.metricsHandler = mockMetrics
        store.setOverride(true, for: "test.metrics-override")

        #expect(mockMetrics.recordedOverrides.count == 1)
        #expect(mockMetrics.recordedOverrides[0].flagID == "test.metrics-override")
        #expect(mockMetrics.recordedOverrides[0].value == true)
    }
}

// MARK: - Mock Metrics Handler

final class MockMetricsHandler: FlagMetricsHandler, @unchecked Sendable {
    struct RecordedCheck: Sendable {
        let flagID: String
        let result: Bool
    }

    struct RecordedOverride: Sendable {
        let flagID: String
        let value: Bool
    }

    var recordedChecks: [RecordedCheck] = []
    var recordedOverrides: [RecordedOverride] = []

    func recordCheck(flagID: String, result: Bool) {
        recordedChecks.append(RecordedCheck(flagID: flagID, result: result))
    }

    func recordOverride(flagID: String, value: Bool) {
        recordedOverrides.append(RecordedOverride(flagID: flagID, value: value))
    }

    func recordCohortAssignment(flagID: String, cohort: String) {
        // Not tracked in tests
    }
}
