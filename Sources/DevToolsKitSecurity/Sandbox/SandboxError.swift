import Foundation

/// Errors related to sandbox validation.
///
/// Since 0.4.0
public enum SandboxError: Error, LocalizedError, Sendable {
    /// The path is outside the allowed directories.
    case accessDenied(path: String)

    public var errorDescription: String? {
        switch self {
        case .accessDenied(let path):
            return "Access denied: Path '\(path)' is outside allowed directories"
        }
    }
}
