import Foundation

/// Performance analyzer for detecting bottlenecks and anti-patterns.
///
/// Detects nested loops, string concatenation in loops, missing capacity
/// reservations, synchronous network calls, and other performance issues.
///
/// ```swift
/// let analyzer = PerformanceAnalyzer()
/// let result = try await analyzer.analyze(file)
/// ```
///
/// > Since: 0.4.0
public struct PerformanceAnalyzer: CodeAnalyzer {

    /// Create a new performance analyzer.
    public init() {}

    /// Analyze a source file for performance issues.
    /// - Parameter file: The source file to analyze.
    /// - Returns: An ``AnalysisResult`` containing detected performance issues and metrics.
    public func analyze(_ file: SourceFile) async throws -> AnalysisResult {
        let startTime = Date()
        var allIssues: [Issue] = []

        // Run all performance checks
        allIssues += PerformancePatterns.detectNestedLoops(in: file)
        allIssues += PerformancePatterns.detectStringConcatInLoop(in: file)
        allIssues += PerformancePatterns.detectArrayAppendWithoutCapacity(in: file)
        allIssues += PerformancePatterns.detectSyncNetworkCalls(in: file)
        allIssues += PerformancePatterns.detectArrayContainsInLoop(in: file)
        allIssues += PerformancePatterns.detectFilterCount(in: file)

        // Sort by line number and severity
        let sortedIssues = allIssues.sorted { lhs, rhs in
            if lhs.line != rhs.line {
                return lhs.line < rhs.line
            }
            return lhs.severity.priority > rhs.severity.priority
        }

        // Calculate metrics
        let metrics = MetricsCalculator.calculate(for: file)

        // Calculate performance score
        let score = calculatePerformanceScore(from: sortedIssues, metrics: metrics)

        let duration = Date().timeIntervalSince(startTime)

        return AnalysisResult(
            file: file.path,
            language: file.language,
            issues: sortedIssues,
            metrics: metrics,
            score: score,
            duration: duration
        )
    }

    /// Calculate performance score.
    private func calculatePerformanceScore(from issues: [Issue], metrics: CodeMetrics) -> QualityScore {
        var performanceScore: Double = 100.0

        for issue in issues where issue.category == .performance {
            switch issue.severity {
            case .error: performanceScore -= 15
            case .warning: performanceScore -= 8
            case .info: performanceScore -= 3
            }
        }

        performanceScore = max(0, performanceScore)

        return QualityScore(
            overall: performanceScore,
            security: 100,
            performance: performanceScore,
            maintainability: metrics.maintainabilityIndex,
            style: 100
        )
    }
}
