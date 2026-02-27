import Foundation

/// How the license backend validates credentials.
///
/// Only meaningful for backends that support both modes (e.g., LicenseSeat).
/// StoreKit validation is always handled by the system.
public enum ValidationMode: String, Sendable, CaseIterable, Codable {
    /// Validate using a locally-provided offline token with no network contact.
    case offline

    /// Validate via the licensing server (requires network).
    case online
}
