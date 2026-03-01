import Foundation

/// Permission level for operation execution.
///
/// Since 0.4.0
public enum PermissionLevel: String, Codable, Sendable, Hashable {
    /// Always allow execution without prompting.
    case allow
    /// Ask user for permission before execution.
    case ask
    /// Always deny execution.
    case deny
}
