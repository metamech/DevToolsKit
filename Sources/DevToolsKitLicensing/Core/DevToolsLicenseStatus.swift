import Foundation

/// Current status of the license as reported by the active backend.
public enum DevToolsLicenseStatus: String, Sendable, Codable {
    /// No backend configured or no license action taken yet.
    case unconfigured

    /// License is active and validated (online).
    case active

    /// License is valid via offline token (no server contact).
    case offlineValid

    /// License was previously active but is now inactive (e.g., deactivated).
    case inactive

    /// License was previously valid but has expired (subscription lapsed or timed license ended).
    case expired

    /// License key or token is invalid.
    case invalid

    /// Validation is in progress.
    case pending
}
