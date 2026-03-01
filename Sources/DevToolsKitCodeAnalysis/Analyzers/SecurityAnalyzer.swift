import Foundation

/// Security analyzer for detecting vulnerabilities in source code.
///
/// Runs pattern-based security rules and contextual analysis to detect
/// hardcoded secrets, SQL injection, command injection, insecure crypto, and more.
///
/// ```swift
/// let analyzer = SecurityAnalyzer()
/// let result = try await analyzer.analyze(file)
/// ```
///
/// > Since: 0.4.0
public struct SecurityAnalyzer: CodeAnalyzer {

    /// Create a new security analyzer.
    public init() {}

    /// Analyze a source file for security vulnerabilities.
    /// - Parameter file: The source file to analyze.
    /// - Returns: An ``AnalysisResult`` containing detected security issues.
    public func analyze(_ file: SourceFile) async throws -> AnalysisResult {
        let startTime = Date()
        var allIssues: [Issue] = []

        // Run all security rules
        let ruleIssues = SecurityPatterns.findMatches(for: SecurityRules.allRules, in: file)
        allIssues.append(contentsOf: ruleIssues)

        // Run contextual analysis
        let contextualIssues = SecurityPatterns.findContextualVulnerabilities(in: file)
        allIssues.append(contentsOf: contextualIssues)

        // Sort issues by severity (errors first) then by line number
        let sortedIssues = allIssues.sorted { lhs, rhs in
            if lhs.severity.priority != rhs.severity.priority {
                return lhs.severity.priority > rhs.severity.priority
            }
            return lhs.line < rhs.line
        }

        let metrics = CodeMetrics()
        let score = calculateSecurityScore(from: sortedIssues)
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

    /// Calculate security score based on issues.
    private func calculateSecurityScore(from issues: [Issue]) -> QualityScore {
        var securityScore: Double = 100.0

        for issue in issues {
            switch issue.severity {
            case .error: securityScore -= 15
            case .warning: securityScore -= 7
            case .info: securityScore -= 2
            }
        }

        securityScore = max(0, securityScore)

        return QualityScore(
            overall: securityScore,
            security: securityScore,
            performance: 100,
            maintainability: 100,
            style: 100
        )
    }

    /// Analyze multiple files for security issues.
    /// - Parameter files: The source files to analyze.
    /// - Returns: A ``BatchAnalysisResult`` with per-file results.
    public static func analyzeBatch(_ files: [SourceFile]) async throws -> BatchAnalysisResult {
        let startTime = Date()
        let analyzer = SecurityAnalyzer()

        var results: [AnalysisResult] = []

        for file in files {
            let result = try await analyzer.analyze(file)
            results.append(result)
        }

        let duration = Date().timeIntervalSince(startTime)

        return BatchAnalysisResult(
            results: results,
            totalDuration: duration
        )
    }

    /// Get security summary statistics from an analysis result.
    /// - Parameter result: The analysis result to summarize.
    /// - Returns: A ``SecuritySummary`` with aggregated statistics.
    public static func securitySummary(from result: AnalysisResult) -> SecuritySummary {
        let criticalIssues = result.issues.filter { $0.severity == .error }
        let warnings = result.issues.filter { $0.severity == .warning }
        let info = result.issues.filter { $0.severity == .info }

        var cweGroups: [String: Int] = [:]
        for issue in result.issues {
            if let cwe = issue.cwe {
                cweGroups[cwe, default: 0] += 1
            }
        }

        return SecuritySummary(
            criticalIssues: criticalIssues.count,
            warnings: warnings.count,
            info: info.count,
            cweBreakdown: cweGroups,
            securityScore: result.score.security
        )
    }
}

// MARK: - Supporting Types

/// Security analysis summary with aggregated statistics.
///
/// > Since: 0.4.0
public struct SecuritySummary: Sendable {
    /// Number of error-severity issues.
    public let criticalIssues: Int
    /// Number of warning-severity issues.
    public let warnings: Int
    /// Number of info-severity issues.
    public let info: Int
    /// Issue counts grouped by CWE identifier.
    public let cweBreakdown: [String: Int]
    /// Security sub-score (0-100).
    public let securityScore: Double

    /// Total number of issues.
    public var totalIssues: Int {
        criticalIssues + warnings + info
    }

    /// Whether any error-severity issues exist.
    public var hasCriticalIssues: Bool {
        criticalIssues > 0
    }

    /// CWE identifiers sorted by frequency (most common first).
    public var topCWEs: [(cwe: String, count: Int)] {
        cweBreakdown.sorted { $0.value > $1.value }.map { (cwe: $0.key, count: $0.value) }
    }

    /// Short summary string.
    public var summary: String {
        "Security: \(criticalIssues) critical, \(warnings) warnings, \(info) info (Score: \(Int(securityScore))/100)"
    }
}
