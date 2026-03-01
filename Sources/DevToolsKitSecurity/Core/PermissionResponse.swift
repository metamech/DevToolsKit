import Foundation

/// Response to a permission request.
///
/// Since 0.4.0
public enum PermissionResponse: Sendable, Codable, Equatable, Hashable {
    /// Allow this single execution.
    case allow
    /// Allow this execution and all future executions of this operation in the current session.
    case allowForSession
    /// Deny this execution.
    case deny
}
