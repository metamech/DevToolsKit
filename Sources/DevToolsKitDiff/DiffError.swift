import Foundation

/// Errors that can occur during diff parsing or application.
///
/// > Since: 0.4.0
public enum DiffError: Error, LocalizedError, Sendable, Equatable {
    /// The diff text is malformed or too short to parse.
    case invalidDiff(String)

    /// A hunk could not be applied to the target file.
    case applicationFailed(String)

    /// The target file could not be read.
    case fileReadFailed(String)

    /// The modified content could not be written.
    case fileWriteFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidDiff(let reason):
            "Invalid diff: \(reason)"
        case .applicationFailed(let reason):
            "Diff application failed: \(reason)"
        case .fileReadFailed(let reason):
            "Failed to read file: \(reason)"
        case .fileWriteFailed(let reason):
            "Failed to write file: \(reason)"
        }
    }
}
