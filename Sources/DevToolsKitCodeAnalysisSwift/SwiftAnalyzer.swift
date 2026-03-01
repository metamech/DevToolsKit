import Foundation
import DevToolsKitCodeAnalysis

/// Static analyzer for Swift source files.
///
/// `SwiftAnalyzer` implements the ``CodeAnalyzer`` protocol and coordinates
/// all Swift-specific analysis passes including complexity analysis, code smell
/// detection, and Swift-specific rules (force unwraps, retain cycles, etc.).
///
/// ```swift
/// let analyzer = SwiftAnalyzer()
/// let result = try await analyzer.analyze(sourceFile)
/// print("Found \(result.issues.count) issues")
/// ```
///
/// > Since: 0.4.0
public struct SwiftAnalyzer: CodeAnalyzer, Sendable {

    /// Creates a new Swift analyzer.
    public init() {}

    /// Analyze a Swift source file.
    ///
    /// Runs complexity analysis, code smell detection, and Swift-specific rules.
    /// For non-Swift files, returns an empty result with metrics only.
    ///
    /// - Parameter file: The source file to analyze.
    /// - Returns: An ``AnalysisResult`` containing detected issues and metrics.
    public func analyze(_ file: SourceFile) async throws -> AnalysisResult {
        let startTime = Date()
        var allIssues: [Issue] = []

        // Only apply Swift-specific rules to Swift files
        guard file.language == .swift else {
            return AnalysisResult(
                file: file.path,
                language: file.language,
                issues: [],
                metrics: MetricsCalculator.calculate(for: file),
                duration: Date().timeIntervalSince(startTime)
            )
        }

        // Language-agnostic analysis passes (from DevToolsKitCodeAnalysis)
        allIssues += ComplexityAnalyzer.analyzeCyclomaticComplexity(file)
        allIssues += ComplexityAnalyzer.analyzeNesting(file)

        allIssues += CodeSmellDetector.detectLongMethods(file)
        allIssues += CodeSmellDetector.detectLargeTypes(file)
        allIssues += CodeSmellDetector.detectUnusedVariables(file)
        allIssues += CodeSmellDetector.detectMagicNumbers(file)
        allIssues += CodeSmellDetector.detectLongParameterLists(file)

        // Swift-specific analysis passes
        allIssues += SwiftSpecificRules.detectForceUnwraps(file)
        allIssues += SwiftSpecificRules.detectImplicitlyUnwrappedOptionals(file)
        allIssues += SwiftSpecificRules.detectPotentialRetainCycles(file)
        allIssues += SwiftSpecificRules.detectEmptyCatchBlocks(file)
        allIssues += SwiftSpecificRules.detectPrintStatements(file)
        allIssues += SwiftSpecificRules.detectTODOComments(file)
        allIssues += SwiftSpecificRules.detectForcedTypeCasting(file)

        let metrics = MetricsCalculator.calculate(for: file)

        // Sort by line number, then severity
        let sortedIssues = allIssues.sorted { lhs, rhs in
            if lhs.line != rhs.line {
                return lhs.line < rhs.line
            }
            return lhs.severity.priority > rhs.severity.priority
        }

        let duration = Date().timeIntervalSince(startTime)

        return AnalysisResult(
            file: file.path,
            language: file.language,
            issues: sortedIssues,
            metrics: metrics,
            duration: duration
        )
    }

    /// Analyze multiple Swift files in batch.
    ///
    /// - Parameter files: The source files to analyze.
    /// - Returns: A ``BatchAnalysisResult`` with results for all files.
    public static func analyzeBatch(_ files: [SourceFile]) async throws -> BatchAnalysisResult {
        let startTime = Date()
        let analyzer = SwiftAnalyzer()

        var results: [AnalysisResult] = []

        for file in files {
            let result = try await analyzer.analyze(file)
            results.append(result)
        }

        let duration = Date().timeIntervalSince(startTime)

        return BatchAnalysisResult(results: results, totalDuration: duration)
    }
}
