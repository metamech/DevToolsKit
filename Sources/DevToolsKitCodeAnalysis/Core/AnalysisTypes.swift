import Foundation

// MARK: - Errors

/// Errors that can occur during code analysis operations.
///
/// > Since: 0.4.0
public enum CodeAnalysisError: Error, Sendable {
    /// The specified file was not found at the given path.
    case fileNotFound(String)
    /// The file could not be read (e.g. encoding issues).
    case unreadableFile(String)
    /// The report format is not supported.
    case unsupportedFormat(String)
}

// MARK: - Severity

/// Severity level of an analysis issue.
///
/// > Since: 0.4.0
public enum Severity: String, Codable, Sendable, CaseIterable {
    /// A critical issue that should be fixed immediately.
    case error
    /// A potential problem that should be reviewed.
    case warning
    /// An informational suggestion for improvement.
    case info

    /// Human-readable display name.
    public var displayName: String {
        rawValue.capitalized
    }

    /// Numeric priority for sorting (higher = more severe).
    public var priority: Int {
        switch self {
        case .error: return 3
        case .warning: return 2
        case .info: return 1
        }
    }
}

// MARK: - Category

/// Category of an analysis issue.
///
/// > Since: 0.4.0
public enum Category: String, Codable, CaseIterable, Sendable {
    /// Security vulnerabilities and risks.
    case security
    /// Performance bottlenecks and inefficiencies.
    case performance
    /// Code style and formatting issues.
    case style
    /// Code complexity and maintainability.
    case complexity
    /// Code duplication and redundancy.
    case duplication

    /// Human-readable display name.
    public var displayName: String {
        rawValue.capitalized
    }

    /// Longer description of the category.
    public var description: String {
        switch self {
        case .security: return "Security vulnerabilities and risks"
        case .performance: return "Performance bottlenecks and inefficiencies"
        case .style: return "Code style and formatting issues"
        case .complexity: return "Code complexity and maintainability"
        case .duplication: return "Code duplication and redundancy"
        }
    }
}

// MARK: - Issue

/// An individual analysis issue detected in a source file.
///
/// Each issue includes a severity, category, location (line/column),
/// a human-readable message, and a recommendation for how to fix it.
///
/// > Since: 0.4.0
public struct Issue: Codable, Sendable, Identifiable {
    /// Unique identifier for this issue instance.
    public let id: UUID
    /// Severity level of the issue.
    public let severity: Severity
    /// Category the issue belongs to.
    public let category: Category
    /// Line number where the issue was detected (1-indexed).
    public let line: Int
    /// Optional column number within the line.
    public let column: Int?
    /// Human-readable description of the issue.
    public let message: String
    /// Suggested fix or improvement.
    public let recommendation: String
    /// Optional rule code (e.g. "SEC-001").
    public let code: String?
    /// Optional CWE identifier (e.g. "CWE-798").
    public let cwe: String?

    /// Create a new analysis issue.
    /// - Parameters:
    ///   - severity: The severity level.
    ///   - category: The issue category.
    ///   - line: Line number (1-indexed).
    ///   - column: Optional column number.
    ///   - message: Human-readable description.
    ///   - recommendation: Suggested fix.
    ///   - code: Optional rule code.
    ///   - cwe: Optional CWE identifier.
    public init(
        severity: Severity,
        category: Category,
        line: Int,
        column: Int? = nil,
        message: String,
        recommendation: String,
        code: String? = nil,
        cwe: String? = nil
    ) {
        self.id = UUID()
        self.severity = severity
        self.category = category
        self.line = line
        self.column = column
        self.message = message
        self.recommendation = recommendation
        self.code = code
        self.cwe = cwe
    }

    /// Full message including CWE reference if available.
    public var fullMessage: String {
        var result = "[\(severity.displayName)] \(message)"
        if let cwe = cwe {
            result += " (\(cwe))"
        }
        return result
    }
}

// MARK: - Code Metrics

/// Code quality metrics computed for a source file.
///
/// Includes line counts, cyclomatic complexity, maintainability index,
/// and duplication percentage.
///
/// > Since: 0.4.0
public struct CodeMetrics: Codable, Sendable {
    /// Number of lines containing code.
    public let linesOfCode: Int
    /// Number of blank lines.
    public let blankLines: Int
    /// Number of comment lines.
    public let commentLines: Int
    /// Cyclomatic complexity score.
    public let cyclomaticComplexity: Int
    /// Maintainability index (0-100, higher is better).
    public let maintainabilityIndex: Double
    /// Percentage of duplicated lines.
    public let duplicationPercentage: Double

    /// Create code metrics with the given values.
    public init(
        linesOfCode: Int = 0,
        blankLines: Int = 0,
        commentLines: Int = 0,
        cyclomaticComplexity: Int = 0,
        maintainabilityIndex: Double = 0.0,
        duplicationPercentage: Double = 0.0
    ) {
        self.linesOfCode = linesOfCode
        self.blankLines = blankLines
        self.commentLines = commentLines
        self.cyclomaticComplexity = cyclomaticComplexity
        self.maintainabilityIndex = maintainabilityIndex
        self.duplicationPercentage = duplicationPercentage
    }

    /// Lines of code minus blank lines and comment lines.
    public var effectiveLinesOfCode: Int {
        linesOfCode - blankLines - commentLines
    }

    /// Human-readable complexity rating based on cyclomatic complexity.
    public var complexityRating: String {
        switch cyclomaticComplexity {
        case 0...5: return "Simple"
        case 6...10: return "Moderate"
        case 11...20: return "Complex"
        default: return "Very Complex"
        }
    }

    /// Human-readable maintainability rating based on maintainability index.
    public var maintainabilityRating: String {
        switch maintainabilityIndex {
        case 85...100: return "Excellent"
        case 65..<85: return "Good"
        case 40..<65: return "Moderate"
        default: return "Poor"
        }
    }
}

// MARK: - Quality Score

/// Overall quality score for analyzed code, broken down by category.
///
/// Scores are clamped to the 0-100 range. Use ``calculate(from:metrics:)``
/// to derive a score from a set of issues and metrics.
///
/// > Since: 0.4.0
public struct QualityScore: Codable, Sendable {
    /// Weighted overall score (0-100).
    public let overall: Double
    /// Security sub-score (0-100).
    public let security: Double
    /// Performance sub-score (0-100).
    public let performance: Double
    /// Maintainability sub-score (0-100).
    public let maintainability: Double
    /// Style sub-score (0-100).
    public let style: Double

    /// Create a quality score with explicit values (clamped to 0-100).
    public init(
        overall: Double = 0.0,
        security: Double = 0.0,
        performance: Double = 0.0,
        maintainability: Double = 0.0,
        style: Double = 0.0
    ) {
        self.overall = min(100, max(0, overall))
        self.security = min(100, max(0, security))
        self.performance = min(100, max(0, performance))
        self.maintainability = min(100, max(0, maintainability))
        self.style = min(100, max(0, style))
    }

    /// Letter grade derived from the overall score.
    public var grade: String {
        switch overall {
        case 90...100: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default: return "F"
        }
    }

    /// Human-readable rating derived from the overall score.
    public var rating: String {
        switch overall {
        case 90...100: return "Excellent"
        case 80..<90: return "Good"
        case 70..<80: return "Fair"
        case 60..<70: return "Poor"
        default: return "Very Poor"
        }
    }

    /// Calculate a quality score from detected issues and computed metrics.
    /// - Parameters:
    ///   - issues: The issues detected during analysis.
    ///   - metrics: The code metrics computed for the file.
    /// - Returns: A ``QualityScore`` with category breakdowns and weighted overall.
    public static func calculate(from issues: [Issue], metrics: CodeMetrics) -> QualityScore {
        let securityIssues = issues.filter { $0.category == .security }
        let performanceIssues = issues.filter { $0.category == .performance }
        let styleIssues = issues.filter { $0.category == .style }

        func calculateCategoryScore(issues: [Issue], baseScore: Double = 100.0) -> Double {
            var score = baseScore
            for issue in issues {
                switch issue.severity {
                case .error: score -= 10
                case .warning: score -= 5
                case .info: score -= 1
                }
            }
            return max(0, score)
        }

        let security = calculateCategoryScore(issues: securityIssues)
        let performance = calculateCategoryScore(issues: performanceIssues)
        let style = calculateCategoryScore(issues: styleIssues)
        let maintainability = min(100, metrics.maintainabilityIndex)

        let overall = (security * 0.3 + performance * 0.25 + maintainability * 0.25 + style * 0.2)

        return QualityScore(
            overall: overall,
            security: security,
            performance: performance,
            maintainability: maintainability,
            style: style
        )
    }
}

// MARK: - Analysis Result

/// Result of analyzing a single source file.
///
/// Contains the detected issues, computed metrics, quality score,
/// and metadata about the analysis run.
///
/// > Since: 0.4.0
public struct AnalysisResult: Codable, Sendable {
    /// Path of the analyzed file.
    public let file: String
    /// Detected programming language.
    public let language: ProgrammingLanguage
    /// Issues detected during analysis.
    public let issues: [Issue]
    /// Computed code metrics.
    public let metrics: CodeMetrics
    /// Quality score derived from issues and metrics.
    public let score: QualityScore
    /// Timestamp when the analysis was performed.
    public let analyzedAt: Date
    /// Wall-clock duration of the analysis.
    public let duration: TimeInterval

    /// Create an analysis result.
    public init(
        file: String,
        language: ProgrammingLanguage,
        issues: [Issue] = [],
        metrics: CodeMetrics = CodeMetrics(),
        score: QualityScore? = nil,
        analyzedAt: Date = Date(),
        duration: TimeInterval = 0
    ) {
        self.file = file
        self.language = language
        self.issues = issues
        self.metrics = metrics
        self.score = score ?? QualityScore.calculate(from: issues, metrics: metrics)
        self.analyzedAt = analyzedAt
        self.duration = duration
    }

    /// Issues grouped by severity.
    public var issuesBySeverity: [Severity: [Issue]] {
        Dictionary(grouping: issues, by: { $0.severity })
    }

    /// Issues grouped by category.
    public var issuesByCategory: [Category: [Issue]] {
        Dictionary(grouping: issues, by: { $0.category })
    }

    /// Number of error-severity issues.
    public var errorCount: Int {
        issues.filter { $0.severity == .error }.count
    }

    /// Number of warning-severity issues.
    public var warningCount: Int {
        issues.filter { $0.severity == .warning }.count
    }

    /// Number of info-severity issues.
    public var infoCount: Int {
        issues.filter { $0.severity == .info }.count
    }

    /// Whether any error-severity issues were found.
    public var hasErrors: Bool {
        errorCount > 0
    }

    /// Short summary string (e.g. "2 errors, 3 warnings, 1 info").
    public var summary: String {
        "\(errorCount) errors, \(warningCount) warnings, \(infoCount) info"
    }
}

// MARK: - Batch Analysis Result

/// Result of analyzing multiple source files.
///
/// > Since: 0.4.0
public struct BatchAnalysisResult: Codable, Sendable {
    /// Per-file analysis results.
    public let results: [AnalysisResult]
    /// Total wall-clock duration of the batch analysis.
    public let totalDuration: TimeInterval
    /// Timestamp when the batch analysis was performed.
    public let analyzedAt: Date

    /// Create a batch analysis result.
    public init(results: [AnalysisResult], totalDuration: TimeInterval = 0, analyzedAt: Date = Date()) {
        self.results = results
        self.totalDuration = totalDuration
        self.analyzedAt = analyzedAt
    }

    /// Total number of issues across all files.
    public var totalIssues: Int {
        results.reduce(0) { $0 + $1.issues.count }
    }

    /// Total error-severity issues across all files.
    public var totalErrors: Int {
        results.reduce(0) { $0 + $1.errorCount }
    }

    /// Total warning-severity issues across all files.
    public var totalWarnings: Int {
        results.reduce(0) { $0 + $1.warningCount }
    }

    /// Total info-severity issues across all files.
    public var totalInfo: Int {
        results.reduce(0) { $0 + $1.infoCount }
    }

    /// Average quality score across all analyzed files.
    public var averageScore: Double {
        guard !results.isEmpty else { return 0 }
        return results.reduce(0) { $0 + $1.score.overall } / Double(results.count)
    }

    /// Short summary string.
    public var summary: String {
        "\(results.count) files analyzed: \(totalErrors) errors, \(totalWarnings) warnings, \(totalInfo) info"
    }
}
