import DevToolsKitLicensing
import Foundation
internal import LicenseSeat

/// License backend for website-distributed apps using LicenseSeat + LemonSqueezy.
///
/// Wraps the LicenseSeat SDK to conform to ``LicenseBackend``. Supports both
/// online license key activation and offline token validation.
///
/// ```swift
/// import DevToolsKitLicensingSeat
///
/// let backend = LicenseSeatBackend(
///     apiKey: "prod_xxx",
///     productSlug: "my-product"
/// )
/// let licensing = LicensingManager(keyPrefix: "myapp", backend: backend)
/// ```
@MainActor
public final class LicenseSeatBackend: LicenseBackend, @unchecked Sendable {
    private let store: LicenseSeatStore
    private let seat: LicenseSeat
    private let entitlementKeys: [String]

    /// Current license status mapped from LicenseSeat's status.
    public private(set) var status: DevToolsLicenseStatus = .unconfigured

    /// Active entitlement names from the LicenseSeat session.
    public private(set) var activeEntitlements: Set<String> = []

    /// - Parameters:
    ///   - apiKey: The LicenseSeat API key.
    ///   - productSlug: The LemonSqueezy product slug for this app.
    ///   - entitlementKeys: Entitlement keys to check against the LicenseSeat API.
    public init(apiKey: String, productSlug: String, entitlementKeys: [String] = []) {
        self.entitlementKeys = entitlementKeys
        self.store = LicenseSeatStore.shared
        store.configure(apiKey: apiKey)

        var config = LicenseSeatConfig.default
        config.apiKey = apiKey
        config.productSlug = productSlug
        self.seat = LicenseSeat(config: config)

        syncStatus()
    }

    public func activate(with credential: LicenseCredential) async throws {
        switch credential {
        case .licenseKey(let key):
            try await store.activate(key)
        case .offlineToken(let token):
            // For offline tokens, activate with the token as a key and rely on
            // the SDK's offline validation path
            try await store.activate(token)
        }
        syncStatus()
    }

    public func validate() async throws {
        guard let license = seat.currentLicense() else {
            throw LicenseSeatBackendError.notConfigured
        }
        _ = try await seat.validate(licenseKey: license.licenseKey)
        syncStatus()
    }

    public func deactivate() async throws {
        try await store.deactivate()
        status = .inactive
        activeEntitlements = []
    }

    private func syncStatus() {
        let seatStatus = store.status
        status = mapStatus(seatStatus)
        activeEntitlements = resolveEntitlements()
    }

    private func mapStatus(_ seatStatus: LicenseStatus) -> DevToolsLicenseStatus {
        switch seatStatus {
        case .active:
            return .active
        case .offlineValid:
            return .offlineValid
        case .inactive:
            return .inactive
        case .invalid, .offlineInvalid:
            return .invalid
        case .pending:
            return .pending
        }
    }

    private func resolveEntitlements() -> Set<String> {
        var entitlements: Set<String> = []
        if status == .active || status == .offlineValid {
            entitlements.insert("premium")
        }
        for key in entitlementKeys {
            let result = store.entitlement(key)
            if result.active {
                entitlements.insert(key)
            }
        }
        return entitlements
    }
}

/// Errors thrown by ``LicenseSeatBackend``.
///
/// Declared locally so the backing LicenseSeat module does not appear in the
/// public import surface of `DevToolsKitLicensingSeat`.
enum LicenseSeatBackendError: Error {
    case notConfigured
}
