import Foundation

/// Protocol for code analyzers that examine source files and produce analysis results.
///
/// Conform to this protocol to create custom analyzers (security, performance,
/// language-specific rules, etc.). Each analyzer receives a ``SourceFile`` and
/// returns an ``AnalysisResult`` containing any detected issues plus metrics.
///
/// ```swift
/// struct MyAnalyzer: CodeAnalyzer {
///     func analyze(_ file: SourceFile) async throws -> AnalysisResult {
///         // detect issues...
///         return AnalysisResult(file: file.path, language: file.language, issues: issues)
///     }
/// }
/// ```
///
/// > Since: 0.4.0
public protocol CodeAnalyzer: Sendable {
    /// Analyze a source file and return results.
    /// - Parameter file: The source file to analyze.
    /// - Returns: An ``AnalysisResult`` containing detected issues and metrics.
    func analyze(_ file: SourceFile) async throws -> AnalysisResult
}
