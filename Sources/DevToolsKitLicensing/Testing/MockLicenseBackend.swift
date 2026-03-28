import Foundation

/// A mock license backend for testing and development.
///
/// Always compiled into `DevToolsKitLicensing` (SPM packages cannot use app build flags).
/// Apps gate instantiation with their own conditional compilation:
///
/// ```swift
/// #if ENABLE_LICENSE_TESTING
/// let backend = MockLicenseBackend(status: .unconfigured)
/// #else
/// let backend = LicenseSeatBackend(apiKey: "...", productSlug: "...")
/// #endif
///
/// let licensing = LicensingManager(keyPrefix: "myapp", backend: backend)
/// ```
///
/// Dead code stripping removes this type from Release binaries when unreferenced.
@MainActor
public final class MockLicenseBackend: LicenseBackend, @unchecked Sendable {

    // MARK: - State

    /// Current simulated license status.
    public var status: DevToolsLicenseStatus

    /// Current simulated active entitlements.
    public var activeEntitlements: Set<String>

    // MARK: - Configuration

    /// Optional delay applied to `activate`/`validate`/`deactivate` for testing async flows.
    public var simulatedDelay: Duration?

    /// Custom handler called during ``activate(with:)``. If `nil`, default simulation runs.
    public var activateHandler: ((LicenseCredential) async throws -> Void)?

    /// Custom handler called during ``validate()``. If `nil`, validation is a no-op.
    public var validateHandler: (() async throws -> Void)?

    /// Custom handler called during ``deactivate()``. If `nil`, default simulation runs.
    public var deactivateHandler: (() async throws -> Void)?

    // MARK: - Init

    /// Create a mock backend with an initial status.
    ///
    /// - Parameters:
    ///   - status: Initial license status. Defaults to `.unconfigured`.
    ///   - entitlements: Initial active entitlements. Defaults to empty.
    public init(
        status: DevToolsLicenseStatus = .unconfigured,
        entitlements: Set<String> = []
    ) {
        self.status = status
        self.activeEntitlements = entitlements
    }

    // MARK: - LicenseBackend Conformance

    public func activate(with credential: LicenseCredential) async throws {
        if let delay = simulatedDelay {
            try await Task.sleep(for: delay)
        }
        if let handler = activateHandler {
            try await handler(credential)
        } else {
            simulateActivation()
        }
    }

    public func validate() async throws {
        if let delay = simulatedDelay {
            try await Task.sleep(for: delay)
        }
        if let handler = validateHandler {
            try await handler()
        }
    }

    public func deactivate() async throws {
        if let delay = simulatedDelay {
            try await Task.sleep(for: delay)
        }
        if let handler = deactivateHandler {
            try await handler()
        } else {
            simulateDeactivation()
        }
    }

    // MARK: - Simulation Controls

    /// Simulate a successful license activation.
    public func simulateActivation() {
        status = .active
        activeEntitlements = ["premium"]
    }

    /// Simulate license expiration.
    public func simulateExpiration() {
        status = .expired
        activeEntitlements = []
    }

    /// Simulate license deactivation.
    public func simulateDeactivation() {
        status = .inactive
        activeEntitlements = []
    }

    /// Set an arbitrary license state for testing.
    ///
    /// - Parameters:
    ///   - newStatus: The status to simulate.
    ///   - entitlements: Active entitlements in this state.
    public func simulateState(_ newStatus: DevToolsLicenseStatus, entitlements: Set<String> = []) {
        status = newStatus
        activeEntitlements = entitlements
    }
}
