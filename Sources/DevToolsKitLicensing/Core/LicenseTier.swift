import Foundation

/// License tier required to access a feature flag.
///
/// Built-in tiers cover common free/premium splits. Use ``custom(_:)`` for
/// entitlement-based gating that maps to LicenseSeat entitlements or StoreKit product IDs.
public enum LicenseTier: Sendable, Hashable, Codable {
    /// Available to all users regardless of license status.
    case free

    /// Requires an active premium license or subscription.
    case premium

    /// Requires a specific named entitlement from the license backend.
    ///
    /// The string maps to a LicenseSeat entitlement name or a StoreKit product
    /// mapping defined at backend initialization.
    case custom(String)
}
