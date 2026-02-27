import DevToolsKitLicensing
import Foundation

/// Mock license backend for testing.
@MainActor
final class MockBackend: LicenseBackend {
    var status: DevToolsLicenseStatus = .unconfigured
    var activeEntitlements: Set<String> = []

    var activateCallCount = 0
    var validateCallCount = 0
    var deactivateCallCount = 0
    var lastCredential: LicenseCredential?

    func activate(with credential: LicenseCredential) async throws {
        activateCallCount += 1
        lastCredential = credential
        status = .active
        activeEntitlements.insert("premium")
    }

    func validate() async throws {
        validateCallCount += 1
    }

    func deactivate() async throws {
        deactivateCallCount += 1
        status = .inactive
        activeEntitlements = []
    }
}
