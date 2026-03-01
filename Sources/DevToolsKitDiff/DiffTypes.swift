import Foundation

/// Represents a complete unified diff between two files.
///
/// A `Diff` contains the file paths and one or more `Hunk` values
/// describing the changes between the original and modified versions.
///
/// > Since: 0.4.0
public struct Diff: Sendable, Equatable {
    /// Path of the original file (from `---` header).
    public let originalFile: String

    /// Path of the modified file (from `+++` header).
    public let modifiedFile: String

    /// The hunks that make up this diff.
    public let hunks: [Hunk]

    /// Creates a new diff.
    /// - Parameters:
    ///   - originalFile: Path of the original file.
    ///   - modifiedFile: Path of the modified file.
    ///   - hunks: The hunks describing changes.
    public init(originalFile: String, modifiedFile: String, hunks: [Hunk]) {
        self.originalFile = originalFile
        self.modifiedFile = modifiedFile
        self.hunks = hunks
    }
}

/// Represents a single hunk in a unified diff.
///
/// A hunk describes a contiguous region of changes with line ranges
/// for both the original and modified files.
///
/// > Since: 0.4.0
public struct Hunk: Sendable, Equatable {
    /// Starting line number in the original file (1-indexed).
    public let originalStart: Int

    /// Number of lines from the original file in this hunk.
    public let originalCount: Int

    /// Starting line number in the modified file (1-indexed).
    public let modifiedStart: Int

    /// Number of lines from the modified file in this hunk.
    public let modifiedCount: Int

    /// The diff lines that make up this hunk.
    public let lines: [DiffLine]

    /// Creates a new hunk.
    /// - Parameters:
    ///   - originalStart: Starting line in the original file (1-indexed).
    ///   - originalCount: Number of original lines.
    ///   - modifiedStart: Starting line in the modified file (1-indexed).
    ///   - modifiedCount: Number of modified lines.
    ///   - lines: The diff lines.
    public init(
        originalStart: Int,
        originalCount: Int,
        modifiedStart: Int,
        modifiedCount: Int,
        lines: [DiffLine]
    ) {
        self.originalStart = originalStart
        self.originalCount = originalCount
        self.modifiedStart = modifiedStart
        self.modifiedCount = modifiedCount
        self.lines = lines
    }
}

/// Represents a single line in a diff hunk.
///
/// > Since: 0.4.0
public enum DiffLine: Sendable, Equatable {
    /// A context line (unchanged, prefixed with space in unified diff).
    case context(String)

    /// An added line (prefixed with `+` in unified diff).
    case addition(String)

    /// A deleted line (prefixed with `-` in unified diff).
    case deletion(String)

    /// The text content of this line, without the diff prefix.
    public var content: String {
        switch self {
        case .context(let s), .addition(let s), .deletion(let s):
            return s
        }
    }
}
