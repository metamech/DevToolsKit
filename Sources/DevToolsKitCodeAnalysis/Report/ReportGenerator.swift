import Foundation

/// Generates analysis reports in various formats.
///
/// ```swift
/// let report = try ReportGenerator.generate(result, format: .markdown)
/// try ReportGenerator.write(report, to: "/tmp/report.md")
/// ```
///
/// > Since: 0.4.0
public struct ReportGenerator: Sendable {

    /// Generate a report for a single analysis result.
    /// - Parameters:
    ///   - result: The analysis result to format.
    ///   - format: The output format.
    /// - Returns: The formatted report string.
    public static func generate(_ result: AnalysisResult, format: ReportFormat) throws -> String {
        switch format {
        case .console:
            return ConsoleFormatter.format(result)
        case .json:
            return try JSONReportFormatter.format(result)
        case .markdown:
            return MarkdownFormatter.format(result)
        }
    }

    /// Generate a report for batch analysis results.
    /// - Parameters:
    ///   - batchResult: The batch analysis result to format.
    ///   - format: The output format.
    /// - Returns: The formatted report string.
    public static func generate(_ batchResult: BatchAnalysisResult, format: ReportFormat) throws -> String {
        switch format {
        case .console:
            return ConsoleFormatter.format(batchResult)
        case .json:
            return try JSONReportFormatter.format(batchResult)
        case .markdown:
            return MarkdownFormatter.format(batchResult)
        }
    }

    /// Write a report string to a file.
    /// - Parameters:
    ///   - report: The report content to write.
    ///   - path: The file path to write to.
    public static func write(_ report: String, to path: String) throws {
        let url = URL(fileURLWithPath: path)
        try report.write(to: url, atomically: true, encoding: .utf8)
    }
}
