import Foundation
import Testing
@testable import DevToolsKitFeatureFlags
import DevToolsKit

// MARK: - Test Feature Enum

enum TestFeature: String, ExperimentalFeatureProtocol, CaseIterable {
    case basic
    case advanced
    case experimental

    var prerequisites: [TestFeature] {
        switch self {
        case .basic: []
        case .advanced: [.basic]
        case .experimental: [.advanced]
        }
    }

    func defaultEnabled(for channel: DistributionChannel) -> Bool {
        switch channel {
        case .website: true
        case .appStore: self == .basic
        }
    }
}

@Suite("ExperimentalFeatureGate")
@MainActor
struct ExperimentalFeatureGateTests {

    private func makeStore(flags: [FeatureFlag]) -> FeatureFlagStore {
        let store = FeatureFlagStore(
            overrideStore: UserDefaultsOverrideStore(keyPrefix: "test.\(UUID().uuidString)")
        )
        store.register(flags)
        return store
    }

    @Test("Feature enabled when store says yes and no prerequisites")
    func enabledNoPrereqs() async throws {
        let store = makeStore(flags: [
            FeatureFlag(id: "basic", name: "Basic", description: "Test", category: "Test", defaultEnabled: true),
        ])
        let gate = ExperimentalFeatureGate<TestFeature>(store: store)
        #expect(gate.isEnabled(.basic))
    }

    @Test("Feature disabled when store says no")
    func disabledByStore() async throws {
        let store = makeStore(flags: [
            FeatureFlag(id: "basic", name: "Basic", description: "Test", category: "Test", defaultEnabled: false),
        ])
        let gate = ExperimentalFeatureGate<TestFeature>(store: store)
        #expect(!gate.isEnabled(.basic))
    }

    @Test("Feature disabled when prerequisite is disabled")
    func prerequisiteChain() async throws {
        let store = makeStore(flags: [
            FeatureFlag(id: "basic", name: "Basic", description: "Test", category: "Test", defaultEnabled: false),
            FeatureFlag(id: "advanced", name: "Advanced", description: "Test", category: "Test", defaultEnabled: true),
        ])
        let gate = ExperimentalFeatureGate<TestFeature>(store: store)
        // Advanced depends on basic, which is disabled
        #expect(!gate.isEnabled(.advanced))
    }

    @Test("Feature enabled when all prerequisites are enabled")
    func allPrereqsMet() async throws {
        let store = makeStore(flags: [
            FeatureFlag(id: "basic", name: "Basic", description: "Test", category: "Test", defaultEnabled: true),
            FeatureFlag(id: "advanced", name: "Advanced", description: "Test", category: "Test", defaultEnabled: true),
        ])
        let gate = ExperimentalFeatureGate<TestFeature>(store: store)
        #expect(gate.isEnabled(.advanced))
    }

    @Test("Deep prerequisite chain")
    func deepChain() async throws {
        let store = makeStore(flags: [
            FeatureFlag(id: "basic", name: "Basic", description: "Test", category: "Test", defaultEnabled: true),
            FeatureFlag(id: "advanced", name: "Advanced", description: "Test", category: "Test", defaultEnabled: true),
            FeatureFlag(id: "experimental", name: "Experimental", description: "Test", category: "Test", defaultEnabled: true),
        ])
        let gate = ExperimentalFeatureGate<TestFeature>(store: store)
        // experimental -> advanced -> basic, all enabled
        #expect(gate.isEnabled(.experimental))
    }

    @Test("Exposes underlying store")
    func storeAccess() async throws {
        let store = makeStore(flags: [])
        let gate = ExperimentalFeatureGate<TestFeature>(store: store)
        #expect(gate.flagStore === store)
    }
}
