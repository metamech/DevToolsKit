import Foundation

/// Output format for analysis reports.
///
/// > Since: 0.4.0
public enum ReportFormat: String, CaseIterable, Sendable {
    /// Plain-text console output with decorations.
    case console
    /// Structured JSON output.
    case json
    /// Markdown-formatted output suitable for documentation or PRs.
    case markdown

    /// Human-readable display name.
    public var displayName: String {
        rawValue.capitalized
    }
}
