import Foundation

/// Formats analysis results as JSON.
///
/// > Since: 0.4.0
public struct JSONReportFormatter: Sendable {

    /// Format a single analysis result as pretty-printed JSON.
    /// - Parameter result: The analysis result to encode.
    /// - Returns: A JSON string.
    public static func format(_ result: AnalysisResult) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(result)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// Format a batch analysis result as pretty-printed JSON.
    /// - Parameter batchResult: The batch result to encode.
    /// - Returns: A JSON string.
    public static func format(_ batchResult: BatchAnalysisResult) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(batchResult)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
