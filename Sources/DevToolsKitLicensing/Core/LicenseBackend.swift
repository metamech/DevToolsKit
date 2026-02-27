import Foundation

/// Credential used to activate a license.
///
/// The credential type depends on the distribution channel:
/// - Website (LicenseSeat): use ``licenseKey(_:)`` for online or ``offlineToken(_:)`` for offline.
/// - App Store (StoreKit): the backend handles purchases internally; no credential is needed.
public enum LicenseCredential: Sendable {
    /// A user-entered license key for online activation via LicenseSeat.
    case licenseKey(String)

    /// A pasted offline token for local-only validation via LicenseSeat.
    case offlineToken(String)
}

/// Protocol for license validation backends.
///
/// `LicensingManager` delegates all license operations to a conforming backend.
/// Two built-in backends are provided:
/// - `LicenseSeatBackend` (in `DevToolsKitLicensingSeat`) for website distribution
/// - `StoreKitBackend` (in `DevToolsKitLicensingStoreKit`) for App Store distribution
@MainActor
public protocol LicenseBackend: Sendable {
    /// Current license status.
    var status: DevToolsLicenseStatus { get }

    /// Set of active entitlement names granted by the current license.
    var activeEntitlements: Set<String> { get }

    /// Activate the license with the given credential.
    ///
    /// - Parameter credential: The license key or offline token.
    /// - Throws: If activation fails (network error, invalid key, etc.).
    func activate(with credential: LicenseCredential) async throws

    /// Re-validate the current license state.
    ///
    /// - Throws: If validation fails.
    func validate() async throws

    /// Deactivate the current license.
    ///
    /// - Throws: If deactivation fails.
    func deactivate() async throws
}
