import Foundation
import Testing

@testable import DevToolsKitLicensing

@Suite(.serialized)
@MainActor
struct MockLicenseBackendTests {
    @Test func defaultStateIsUnconfigured() {
        let backend = MockLicenseBackend()
        #expect(backend.status == .unconfigured)
        #expect(backend.activeEntitlements.isEmpty)
    }

    @Test func licensedFactoryMethod() {
        let backend = MockLicenseBackend.licensed()
        #expect(backend.status == .active)
        #expect(backend.activeEntitlements.contains("premium"))
    }

    @Test func simulateActivation() {
        let backend = MockLicenseBackend()
        backend.simulateActivation()
        #expect(backend.status == .active)
        #expect(backend.activeEntitlements.contains("premium"))
    }

    @Test func simulateExpiration() {
        let backend = MockLicenseBackend.licensed()
        backend.simulateExpiration()
        #expect(backend.status == .expired)
        #expect(backend.activeEntitlements.isEmpty)
    }

    @Test func simulateDeactivation() {
        let backend = MockLicenseBackend.licensed()
        backend.simulateDeactivation()
        #expect(backend.status == .inactive)
        #expect(backend.activeEntitlements.isEmpty)
    }

    @Test func simulateArbitraryState() {
        let backend = MockLicenseBackend()
        backend.simulateState(.offlineValid, entitlements: ["premium", "enterprise"])
        #expect(backend.status == .offlineValid)
        #expect(backend.activeEntitlements == ["premium", "enterprise"])
    }

    @Test func activateCallsHandler() async throws {
        let backend = MockLicenseBackend()
        var handlerCalled = false
        backend.activateHandler = { _ in handlerCalled = true }
        try await backend.activate(with: .licenseKey("test"))
        #expect(handlerCalled)
        // Handler doesn't change status automatically
        #expect(backend.status == .unconfigured)
    }

    @Test func activateDefaultSimulatesActivation() async throws {
        let backend = MockLicenseBackend()
        try await backend.activate(with: .licenseKey("test"))
        #expect(backend.status == .active)
        #expect(backend.activeEntitlements.contains("premium"))
    }
}
