import Foundation
import os

/// Engine for parsing, applying, and validating unified diffs.
///
/// `DiffEngine` provides methods to parse unified diff text into structured
/// ``Diff`` values, apply diffs to files on disk (with backup and dry-run support),
/// and validate diff structure.
///
/// ```swift
/// let engine = DiffEngine()
/// let diff = try engine.parse(diffText)
/// let warnings = engine.validate(diff)
/// try engine.apply(diff, to: fileURL, dryRun: false)
/// ```
///
/// > Since: 0.4.0
public struct DiffEngine: Sendable {
    private static let logger = Logger(
        subsystem: "com.devtoolskit.diff",
        category: "DiffEngine"
    )

    /// Creates a new diff engine.
    public init() {}

    // MARK: - Parsing

    /// Parses unified diff text into a structured ``Diff``.
    ///
    /// The input should be in standard unified diff format with `---`/`+++`
    /// headers and `@@ ... @@` hunk markers.
    ///
    /// - Parameter diffText: The unified diff text to parse.
    /// - Returns: A parsed ``Diff`` value.
    /// - Throws: ``DiffError/invalidDiff(_:)`` if the text cannot be parsed.
    public func parse(_ diffText: String) throws -> Diff {
        let lines = diffText.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        guard lines.count >= 2 else {
            throw DiffError.invalidDiff("Diff too short")
        }

        // Parse file headers
        var originalFile = ""
        var modifiedFile = ""
        var currentLine = 0

        // Find --- line
        while currentLine < lines.count {
            if lines[currentLine].hasPrefix("---") {
                originalFile = String(
                    lines[currentLine].dropFirst(4).trimmingCharacters(in: .whitespaces)
                )
                currentLine += 1
                break
            }
            currentLine += 1
        }

        // Find +++ line
        if currentLine < lines.count && lines[currentLine].hasPrefix("+++") {
            modifiedFile = String(
                lines[currentLine].dropFirst(4).trimmingCharacters(in: .whitespaces)
            )
            currentLine += 1
        }

        // Parse hunks
        var hunks: [Hunk] = []

        while currentLine < lines.count {
            let line = lines[currentLine]

            if line.hasPrefix("@@") {
                let hunk = try parseHunk(lines: lines, startIndex: &currentLine)
                hunks.append(hunk)
            } else {
                currentLine += 1
            }
        }

        return Diff(originalFile: originalFile, modifiedFile: modifiedFile, hunks: hunks)
    }

    // MARK: - Application

    /// Applies a diff to a file on disk.
    ///
    /// When `dryRun` is `false`, a backup of the original file is created
    /// before modification. If the write fails, the backup is restored.
    ///
    /// - Parameters:
    ///   - diff: The diff to apply.
    ///   - fileURL: The file to modify.
    ///   - dryRun: When `true`, validates that the diff can be applied without modifying the file.
    /// - Throws: ``DiffError`` if the file cannot be read, the diff cannot be applied,
    ///   or the modified content cannot be written.
    public func apply(_ diff: Diff, to fileURL: URL, dryRun: Bool = false) throws {
        let originalContent: String
        do {
            originalContent = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw DiffError.fileReadFailed(fileURL.path)
        }

        let originalLines = originalContent
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        var modifiedLines = originalLines

        // Apply each hunk in reverse order to preserve line numbers
        for hunk in diff.hunks.reversed() {
            modifiedLines = try applyHunk(hunk, to: modifiedLines)
        }

        let modifiedContent = modifiedLines.joined(separator: "\n")

        if !dryRun {
            // Create backup
            let backupURL = fileURL.appendingPathExtension("devtoolskit-diff-backup")

            do {
                try FileManager.default.copyItem(at: fileURL, to: backupURL)
            } catch {
                Self.logger.warning("Could not create backup: \(error.localizedDescription)")
            }

            do {
                try modifiedContent.write(to: fileURL, atomically: true, encoding: .utf8)
                // Remove backup on success
                try? FileManager.default.removeItem(at: backupURL)
            } catch {
                // Restore backup on failure
                try? FileManager.default.removeItem(at: fileURL)
                try? FileManager.default.moveItem(at: backupURL, to: fileURL)
                throw DiffError.fileWriteFailed(fileURL.path)
            }
        }
    }

    /// Applies a diff to in-memory content and returns the result.
    ///
    /// - Parameters:
    ///   - diff: The diff to apply.
    ///   - content: The original file content.
    /// - Returns: The modified content after applying all hunks.
    /// - Throws: ``DiffError/applicationFailed(_:)`` if a hunk cannot be applied.
    public func apply(_ diff: Diff, to content: String) throws -> String {
        let originalLines = content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        var modifiedLines = originalLines

        for hunk in diff.hunks.reversed() {
            modifiedLines = try applyHunk(hunk, to: modifiedLines)
        }

        return modifiedLines.joined(separator: "\n")
    }

    // MARK: - Validation

    /// Validates the structure of a diff and returns any warnings.
    ///
    /// - Parameter diff: The diff to validate.
    /// - Returns: An array of warning messages. An empty array indicates a valid diff.
    public func validate(_ diff: Diff) -> [String] {
        var warnings: [String] = []

        if diff.hunks.isEmpty {
            warnings.append("Diff contains no hunks")
        }

        for (index, hunk) in diff.hunks.enumerated() {
            if hunk.originalCount == 0 && hunk.modifiedCount == 0 {
                warnings.append("Hunk \(index + 1) has zero line counts")
            }

            if hunk.lines.isEmpty {
                warnings.append("Hunk \(index + 1) has no lines")
            }
        }

        return warnings
    }

    // MARK: - Private

    private func parseHunk(lines: [String], startIndex: inout Int) throws -> Hunk {
        let headerLine = lines[startIndex]
        startIndex += 1

        guard let ranges = headerLine.range(
            of: #"@@\s*-(\d+),(\d+)\s+\+(\d+),(\d+)\s*@@"#,
            options: .regularExpression
        ) else {
            throw DiffError.invalidDiff("Invalid hunk header: \(headerLine)")
        }

        let rangeText = String(headerLine[ranges])
        let numbers = rangeText
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }

        guard numbers.count >= 4 else {
            throw DiffError.invalidDiff("Could not parse hunk numbers")
        }

        let originalStart = numbers[0]
        let originalCount = numbers[1]
        let modifiedStart = numbers[2]
        let modifiedCount = numbers[3]

        var hunkLines: [DiffLine] = []

        while startIndex < lines.count {
            let line = lines[startIndex]

            if line.hasPrefix("@@") {
                break
            } else if line.hasPrefix("+") {
                hunkLines.append(.addition(String(line.dropFirst())))
                startIndex += 1
            } else if line.hasPrefix("-") {
                hunkLines.append(.deletion(String(line.dropFirst())))
                startIndex += 1
            } else if line.hasPrefix(" ") || line.isEmpty {
                hunkLines.append(.context(line.isEmpty ? "" : String(line.dropFirst())))
                startIndex += 1
            } else {
                break
            }
        }

        return Hunk(
            originalStart: originalStart,
            originalCount: originalCount,
            modifiedStart: modifiedStart,
            modifiedCount: modifiedCount,
            lines: hunkLines
        )
    }

    private func applyHunk(_ hunk: Hunk, to lines: [String]) throws -> [String] {
        var result = lines
        let startIndex = hunk.originalStart - 1  // Convert to 0-indexed

        guard startIndex >= 0 && startIndex <= result.count else {
            throw DiffError.applicationFailed(
                "Hunk start line out of range: \(hunk.originalStart)"
            )
        }

        var currentIndex = startIndex
        for diffLine in hunk.lines {
            switch diffLine {
            case .context(let content), .deletion(let content):
                if currentIndex < result.count && result[currentIndex] != content {
                    Self.logger.warning("Context mismatch at line \(currentIndex + 1)")
                }
                if case .deletion = diffLine {
                    if currentIndex < result.count {
                        result.remove(at: currentIndex)
                    }
                } else {
                    currentIndex += 1
                }
            case .addition(let content):
                result.insert(content, at: currentIndex)
                currentIndex += 1
            }
        }

        return result
    }
}
