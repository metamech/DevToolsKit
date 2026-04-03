import Testing
@testable import DevToolsKitLicensing
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

    @Test("Feature enabled when licensing manager says yes and no prerequisites")
    func enabledNoPrereqs() async throws {
        let manager = LicensingManager(keyPrefix: "test", backend: MockLicenseBackend())
        manager.registerFlags([
            FeatureFlagDefinition(id: "basic", name: "Basic", description: "Test", category: "Test", defaultEnabled: true),
        ])
        let gate = ExperimentalFeatureGate<TestFeature>(licensingManager: manager)
        #expect(gate.isEnabled(.basic))
    }

    @Test("Feature disabled when licensing manager says no")
    func disabledByManager() async throws {
        let manager = LicensingManager(keyPrefix: "test", backend: MockLicenseBackend())
        manager.registerFlags([
            FeatureFlagDefinition(id: "basic", name: "Basic", description: "Test", category: "Test", defaultEnabled: false),
        ])
        let gate = ExperimentalFeatureGate<TestFeature>(licensingManager: manager)
        #expect(!gate.isEnabled(.basic))
    }

    @Test("Feature disabled when prerequisite is disabled")
    func prerequisiteChain() async throws {
        let manager = LicensingManager(keyPrefix: "test", backend: MockLicenseBackend())
        manager.registerFlags([
            FeatureFlagDefinition(id: "basic", name: "Basic", description: "Test", category: "Test", defaultEnabled: false),
            FeatureFlagDefinition(id: "advanced", name: "Advanced", description: "Test", category: "Test", defaultEnabled: true),
        ])
        let gate = ExperimentalFeatureGate<TestFeature>(licensingManager: manager)
        // Advanced depends on basic, which is disabled
        #expect(!gate.isEnabled(.advanced))
    }

    @Test("Feature enabled when all prerequisites are enabled")
    func allPrereqsMet() async throws {
        let manager = LicensingManager(keyPrefix: "test", backend: MockLicenseBackend())
        manager.registerFlags([
            FeatureFlagDefinition(id: "basic", name: "Basic", description: "Test", category: "Test", defaultEnabled: true),
            FeatureFlagDefinition(id: "advanced", name: "Advanced", description: "Test", category: "Test", defaultEnabled: true),
        ])
        let gate = ExperimentalFeatureGate<TestFeature>(licensingManager: manager)
        #expect(gate.isEnabled(.advanced))
    }

    @Test("Deep prerequisite chain")
    func deepChain() async throws {
        let manager = LicensingManager(keyPrefix: "test", backend: MockLicenseBackend())
        manager.registerFlags([
            FeatureFlagDefinition(id: "basic", name: "Basic", description: "Test", category: "Test", defaultEnabled: true),
            FeatureFlagDefinition(id: "advanced", name: "Advanced", description: "Test", category: "Test", defaultEnabled: true),
            FeatureFlagDefinition(id: "experimental", name: "Experimental", description: "Test", category: "Test", defaultEnabled: true),
        ])
        let gate = ExperimentalFeatureGate<TestFeature>(licensingManager: manager)
        // experimental -> advanced -> basic, all enabled
        #expect(gate.isEnabled(.experimental))
    }

    @Test("Exposes underlying manager")
    func managerAccess() async throws {
        let manager = LicensingManager(keyPrefix: "test", backend: MockLicenseBackend())
        let gate = ExperimentalFeatureGate<TestFeature>(licensingManager: manager)
        #expect(gate.manager === manager)
    }
}
