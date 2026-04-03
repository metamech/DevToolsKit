import Foundation

/// Parses simple YAML frontmatter from markdown files.
///
/// Expects `---` delimiters with flat `key: value` lines between them.
/// Handles double-quoted values (including escaped quotes and newlines).
/// Does not support nested YAML structures.
///
/// ```swift
/// let content = """
/// ---
/// title: My Document
/// author: "Jane Doe"
/// ---
/// # Hello World
/// """
/// let result = YAMLFrontmatterParser.parse(content)
/// print(result.frontmatter["title"]) // Optional("My Document")
/// print(result.body)                 // "# Hello World\n"
/// ```
///
/// - Since: 0.9.0
public enum YAMLFrontmatterParser {

    /// The result of parsing a markdown file with optional frontmatter.
    public struct Result: Sendable {
        /// Key-value pairs extracted from the frontmatter block.
        public let frontmatter: [String: String]

        /// The content following the closing `---` delimiter.
        public let body: String

        /// Creates a parse result.
        ///
        /// - Parameters:
        ///   - frontmatter: The parsed key-value pairs.
        ///   - body: The body content after the frontmatter.
        public init(frontmatter: [String: String], body: String) {
            self.frontmatter = frontmatter
            self.body = body
        }
    }

    /// Parse frontmatter from markdown content.
    ///
    /// Returns empty frontmatter if no valid `---` delimiters are found.
    ///
    /// - Parameter content: The full markdown string to parse.
    /// - Returns: A ``Result`` containing the frontmatter dictionary and body text.
    public static func parse(_ content: String) -> Result {
        let lines = content.components(separatedBy: .newlines)
        guard let firstLine = lines.first,
              firstLine.trimmingCharacters(in: .whitespaces) == "---" else {
            return Result(frontmatter: [:], body: content)
        }

        // Find closing ---
        var closingIndex: Int?
        for i in 1..<lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                closingIndex = i
                break
            }
        }

        guard let endIndex = closingIndex else {
            return Result(frontmatter: [:], body: content)
        }

        // Parse key: value pairs between the delimiters
        var frontmatter: [String: String] = [:]
        for i in 1..<endIndex {
            let line = lines[i]
            guard let colonRange = line.range(of: ":") else { continue }
            let key = line[line.startIndex..<colonRange.lowerBound]
                .trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            var value = line[colonRange.upperBound...]
                .trimmingCharacters(in: .whitespaces)
            // Strip surrounding double quotes
            if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                value = String(value.dropFirst().dropLast())
                // Unescape basic sequences
                value = value.replacingOccurrences(of: "\\\"", with: "\"")
                value = value.replacingOccurrences(of: "\\n", with: "\n")
            }
            frontmatter[key] = value
        }

        // Body is everything after the closing ---
        let bodyLines = Array(lines[(endIndex + 1)...])
        let body = bodyLines.joined(separator: "\n")

        return Result(frontmatter: frontmatter, body: body)
    }
}
