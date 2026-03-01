import Foundation

/// Represents a source file loaded for analysis.
///
/// Provides convenient accessors for line-based operations
/// (get line by number, get context around a line, etc.).
///
/// ```swift
/// let file = try SourceFile.load(from: fileURL)
/// let issues = SecurityPatterns.findMatches(for: SecurityRules.allRules, in: file)
/// ```
///
/// > Since: 0.4.0
public struct SourceFile: Sendable {
    /// File path (absolute or relative).
    public let path: String
    /// Full text content of the file.
    public let content: String
    /// Detected or explicitly provided programming language.
    public let language: ProgrammingLanguage

    /// Create a source file from a path and content string.
    /// - Parameters:
    ///   - path: The file path.
    ///   - content: The full text content.
    ///   - language: The programming language; auto-detected from path if nil.
    public init(path: String, content: String, language: ProgrammingLanguage? = nil) {
        self.path = path
        self.content = content
        self.language = language ?? LanguageDetector.detect(filename: path)
    }

    /// Load a source file from a URL on disk.
    /// - Parameter url: The file URL to load.
    /// - Throws: ``CodeAnalysisError/fileNotFound(_:)`` if the file does not exist,
    ///           ``CodeAnalysisError/unreadableFile(_:)`` if the file cannot be read.
    /// - Returns: A ``SourceFile`` with content read from disk.
    public static func load(from url: URL) throws -> SourceFile {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CodeAnalysisError.fileNotFound(url.path)
        }

        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw CodeAnalysisError.unreadableFile(url.path)
        }

        let language = LanguageDetector.detect(path: url)

        return SourceFile(path: url.path, content: content, language: language)
    }

    /// All lines of the file, split by newlines.
    public var lines: [String] {
        content.components(separatedBy: .newlines)
    }

    /// Total number of lines.
    public var lineCount: Int {
        lines.count
    }

    /// Get a specific line (1-indexed).
    /// - Parameter index: The 1-based line number.
    /// - Returns: The line content, or nil if out of range.
    public func line(at index: Int) -> String? {
        guard index > 0 && index <= lines.count else { return nil }
        return lines[index - 1]
    }

    /// Get a range of lines (1-indexed, half-open).
    /// - Parameter range: The half-open range of 1-based line numbers.
    /// - Returns: An array of line strings within the range.
    public func lines(in range: Range<Int>) -> [String] {
        let start = max(0, range.lowerBound - 1)
        let end = min(lines.count, range.upperBound)
        guard start < end else { return [] }
        return Array(lines[start..<end])
    }

    /// Get context lines around a given line number.
    /// - Parameters:
    ///   - line: The 1-based center line number.
    ///   - contextLines: Number of lines to include above and below.
    /// - Returns: An array of line strings forming the context window.
    public func context(around line: Int, contextLines: Int = 2) -> [String] {
        let start = max(1, line - contextLines)
        let end = min(lineCount, line + contextLines) + 1
        return lines(in: start..<end)
    }
}
