import Foundation

/// Source of a permission configuration.
///
/// Since 0.4.0
public enum PermissionSource: String, Codable, Sendable, Hashable {
    /// Permission from app-wide defaults.
    case appDefault
    /// Permission from project-specific override.
    case projectOverride
    /// Permission from session-specific "Allow Always" choice.
    case sessionOverride
}
