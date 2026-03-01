import Foundation
import Testing
@testable import DevToolsKitCodeAnalysis

@Suite("Analysis Types")
struct AnalysisTypesTests {

    // MARK: - Severity Tests

    @Test("Severity display names")
    func severityDisplayName() {
        #expect(Severity.error.displayName == "Error")
        #expect(Severity.warning.displayName == "Warning")
        #expect(Severity.info.displayName == "Info")
    }

    @Test("Severity priority ordering")
    func severityPriority() {
        #expect(Severity.error.priority == 3)
        #expect(Severity.warning.priority == 2)
        #expect(Severity.info.priority == 1)
        #expect(Severity.error.priority > Severity.warning.priority)
        #expect(Severity.warning.priority > Severity.info.priority)
    }

    // MARK: - Category Tests

    @Test("Category display names")
    func categoryDisplayNames() {
        #expect(Category.security.displayName == "Security")
        #expect(Category.performance.displayName == "Performance")
        #expect(Category.style.displayName == "Style")
        #expect(Category.complexity.displayName == "Complexity")
        #expect(Category.duplication.displayName == "Duplication")
    }

    @Test("Category descriptions are non-empty")
    func categoryDescriptions() {
        #expect(!Category.security.description.isEmpty)
        #expect(!Category.performance.description.isEmpty)
        #expect(Category.security.description.contains("Security"))
    }

    @Test("Category has all expected cases")
    func categoryAllCases() {
        #expect(Category.allCases.count == 5)
        #expect(Category.allCases.contains(.security))
        #expect(Category.allCases.contains(.performance))
    }

    // MARK: - Issue Tests

    @Test("Issue creation with all fields")
    func issueCreation() {
        let issue = Issue(
            severity: .error,
            category: .security,
            line: 42,
            column: 10,
            message: "Security issue",
            recommendation: "Fix it",
            code: "SEC-001",
            cwe: "CWE-798"
        )

        #expect(issue.severity == .error)
        #expect(issue.category == .security)
        #expect(issue.line == 42)
        #expect(issue.column == 10)
        #expect(issue.message == "Security issue")
        #expect(issue.recommendation == "Fix it")
        #expect(issue.code == "SEC-001")
        #expect(issue.cwe == "CWE-798")
    }

    @Test("Issue full message includes CWE when present")
    func issueFullMessage() {
        let issueWithCWE = Issue(
            severity: .error,
            category: .security,
            line: 1,
            message: "Hardcoded password",
            recommendation: "Use environment variable",
            cwe: "CWE-798"
        )
        #expect(issueWithCWE.fullMessage.contains("Error"))
        #expect(issueWithCWE.fullMessage.contains("Hardcoded password"))
        #expect(issueWithCWE.fullMessage.contains("CWE-798"))

        let issueWithoutCWE = Issue(
            severity: .warning,
            category: .performance,
            line: 1,
            message: "Inefficient loop",
            recommendation: "Optimize"
        )
        #expect(issueWithoutCWE.fullMessage.contains("Warning"))
        #expect(!issueWithoutCWE.fullMessage.contains("CWE"))
    }

    @Test("Each issue gets a unique ID")
    func issueIdentifiable() {
        let issue1 = Issue(severity: .error, category: .security, line: 1, message: "Test", recommendation: "Fix")
        let issue2 = Issue(severity: .error, category: .security, line: 1, message: "Test", recommendation: "Fix")
        #expect(issue1.id != issue2.id)
    }

    // MARK: - CodeMetrics Tests

    @Test("CodeMetrics creation")
    func codeMetricsCreation() {
        let metrics = CodeMetrics(
            linesOfCode: 100,
            blankLines: 10,
            commentLines: 15,
            cyclomaticComplexity: 8,
            maintainabilityIndex: 75.5,
            duplicationPercentage: 5.0
        )

        #expect(metrics.linesOfCode == 100)
        #expect(metrics.blankLines == 10)
        #expect(metrics.commentLines == 15)
        #expect(metrics.cyclomaticComplexity == 8)
        #expect(metrics.maintainabilityIndex == 75.5)
        #expect(metrics.duplicationPercentage == 5.0)
    }

    @Test("CodeMetrics effective LOC calculation")
    func codeMetricsEffectiveLOC() {
        let metrics = CodeMetrics(linesOfCode: 100, blankLines: 10, commentLines: 15)
        #expect(metrics.effectiveLinesOfCode == 75)
    }

    @Test("CodeMetrics complexity ratings")
    func codeMetricsComplexityRating() {
        #expect(CodeMetrics(cyclomaticComplexity: 3).complexityRating == "Simple")
        #expect(CodeMetrics(cyclomaticComplexity: 7).complexityRating == "Moderate")
        #expect(CodeMetrics(cyclomaticComplexity: 15).complexityRating == "Complex")
        #expect(CodeMetrics(cyclomaticComplexity: 25).complexityRating == "Very Complex")
    }

    @Test("CodeMetrics maintainability ratings")
    func codeMetricsMaintainabilityRating() {
        #expect(CodeMetrics(maintainabilityIndex: 90).maintainabilityRating == "Excellent")
        #expect(CodeMetrics(maintainabilityIndex: 70).maintainabilityRating == "Good")
        #expect(CodeMetrics(maintainabilityIndex: 50).maintainabilityRating == "Moderate")
        #expect(CodeMetrics(maintainabilityIndex: 30).maintainabilityRating == "Poor")
    }

    // MARK: - QualityScore Tests

    @Test("QualityScore creation")
    func qualityScoreCreation() {
        let score = QualityScore(
            overall: 85.0,
            security: 90.0,
            performance: 80.0,
            maintainability: 85.0,
            style: 90.0
        )

        #expect(score.overall == 85.0)
        #expect(score.security == 90.0)
        #expect(score.performance == 80.0)
        #expect(score.maintainability == 85.0)
        #expect(score.style == 90.0)
    }

    @Test("QualityScore bounds clamping")
    func qualityScoreBounds() {
        let score = QualityScore(
            overall: 150.0,
            security: -10.0,
            performance: 50.0,
            maintainability: 50.0,
            style: 50.0
        )

        #expect(score.overall == 100.0)
        #expect(score.security == 0.0)
    }

    @Test("QualityScore grade letters")
    func qualityScoreGrade() {
        #expect(QualityScore(overall: 95).grade == "A")
        #expect(QualityScore(overall: 85).grade == "B")
        #expect(QualityScore(overall: 75).grade == "C")
        #expect(QualityScore(overall: 65).grade == "D")
        #expect(QualityScore(overall: 50).grade == "F")
    }

    @Test("QualityScore rating strings")
    func qualityScoreRating() {
        #expect(QualityScore(overall: 95).rating == "Excellent")
        #expect(QualityScore(overall: 85).rating == "Good")
        #expect(QualityScore(overall: 75).rating == "Fair")
        #expect(QualityScore(overall: 65).rating == "Poor")
        #expect(QualityScore(overall: 50).rating == "Very Poor")
    }

    @Test("QualityScore calculation from issues and metrics")
    func qualityScoreCalculation() {
        let issues = [
            Issue(severity: .error, category: .security, line: 1, message: "Security issue", recommendation: "Fix"),
            Issue(severity: .warning, category: .performance, line: 2, message: "Performance issue", recommendation: "Optimize"),
            Issue(severity: .info, category: .style, line: 3, message: "Style issue", recommendation: "Format"),
        ]

        let metrics = CodeMetrics(maintainabilityIndex: 80)
        let score = QualityScore.calculate(from: issues, metrics: metrics)

        #expect(score.security == 90.0)
        #expect(score.performance == 95.0)
        #expect(score.style == 99.0)
        #expect(score.maintainability == 80.0)
        #expect(score.overall > 0)
        #expect(score.overall <= 100)
    }

    // MARK: - AnalysisResult Tests

    @Test("AnalysisResult creation")
    func analysisResultCreation() {
        let issues = [
            Issue(severity: .error, category: .security, line: 1, message: "Error", recommendation: "Fix"),
            Issue(severity: .warning, category: .performance, line: 2, message: "Warning", recommendation: "Optimize"),
        ]

        let metrics = CodeMetrics(linesOfCode: 100, cyclomaticComplexity: 5)

        let result = AnalysisResult(
            file: "test.swift",
            language: .swift,
            issues: issues,
            metrics: metrics
        )

        #expect(result.file == "test.swift")
        #expect(result.language == .swift)
        #expect(result.issues.count == 2)
        #expect(result.metrics.linesOfCode == 100)
    }

    @Test("AnalysisResult issue counts")
    func analysisResultIssueCounts() {
        let issues = [
            Issue(severity: .error, category: .security, line: 1, message: "Error 1", recommendation: "Fix"),
            Issue(severity: .error, category: .security, line: 2, message: "Error 2", recommendation: "Fix"),
            Issue(severity: .warning, category: .performance, line: 3, message: "Warning", recommendation: "Optimize"),
            Issue(severity: .info, category: .style, line: 4, message: "Info", recommendation: "Format"),
        ]

        let result = AnalysisResult(file: "test.swift", language: .swift, issues: issues)

        #expect(result.errorCount == 2)
        #expect(result.warningCount == 1)
        #expect(result.infoCount == 1)
        #expect(result.hasErrors)
    }

    @Test("AnalysisResult grouping by severity and category")
    func analysisResultIssuesGrouping() {
        let issues = [
            Issue(severity: .error, category: .security, line: 1, message: "Error", recommendation: "Fix"),
            Issue(severity: .warning, category: .security, line: 2, message: "Warning", recommendation: "Fix"),
            Issue(severity: .info, category: .performance, line: 3, message: "Info", recommendation: "Optimize"),
        ]

        let result = AnalysisResult(file: "test.swift", language: .swift, issues: issues)

        #expect(result.issuesBySeverity[.error]?.count == 1)
        #expect(result.issuesBySeverity[.warning]?.count == 1)
        #expect(result.issuesByCategory[.security]?.count == 2)
        #expect(result.issuesByCategory[.performance]?.count == 1)
    }

    @Test("AnalysisResult summary string")
    func analysisResultSummary() {
        let issues = [
            Issue(severity: .error, category: .security, line: 1, message: "Error", recommendation: "Fix"),
            Issue(severity: .warning, category: .performance, line: 2, message: "Warning", recommendation: "Fix"),
            Issue(severity: .info, category: .style, line: 3, message: "Info", recommendation: "Fix"),
        ]

        let result = AnalysisResult(file: "test.swift", language: .swift, issues: issues)
        #expect(result.summary == "1 errors, 1 warnings, 1 info")
    }

    // MARK: - BatchAnalysisResult Tests

    @Test("BatchAnalysisResult creation and aggregation")
    func batchAnalysisResultCreation() {
        let result1 = AnalysisResult(
            file: "file1.swift",
            language: .swift,
            issues: [Issue(severity: .error, category: .security, line: 1, message: "Error", recommendation: "Fix")]
        )

        let result2 = AnalysisResult(
            file: "file2.swift",
            language: .swift,
            issues: [
                Issue(severity: .warning, category: .performance, line: 1, message: "Warning", recommendation: "Fix"),
                Issue(severity: .info, category: .style, line: 2, message: "Info", recommendation: "Fix"),
            ]
        )

        let batchResult = BatchAnalysisResult(results: [result1, result2])

        #expect(batchResult.results.count == 2)
        #expect(batchResult.totalIssues == 3)
        #expect(batchResult.totalErrors == 1)
        #expect(batchResult.totalWarnings == 1)
        #expect(batchResult.totalInfo == 1)
    }

    @Test("BatchAnalysisResult average score")
    func batchAnalysisResultAverageScore() {
        let result1 = AnalysisResult(file: "file1.swift", language: .swift, score: QualityScore(overall: 80))
        let result2 = AnalysisResult(file: "file2.swift", language: .swift, score: QualityScore(overall: 90))

        let batchResult = BatchAnalysisResult(results: [result1, result2])
        #expect(batchResult.averageScore == 85.0)
    }

    @Test("BatchAnalysisResult empty results")
    func batchAnalysisResultEmptyResults() {
        let batchResult = BatchAnalysisResult(results: [])
        #expect(batchResult.totalIssues == 0)
        #expect(batchResult.averageScore == 0.0)
    }

    @Test("BatchAnalysisResult summary string")
    func batchAnalysisResultSummary() {
        let result1 = AnalysisResult(file: "file1.swift", language: .swift)
        let result2 = AnalysisResult(file: "file2.swift", language: .swift)

        let batchResult = BatchAnalysisResult(results: [result1, result2])
        #expect(batchResult.summary.contains("2 files"))
        #expect(batchResult.summary.contains("errors"))
        #expect(batchResult.summary.contains("warnings"))
    }

    // MARK: - Codable Tests

    @Test("Issue round-trips through JSON encoding")
    func issueCodable() throws {
        let issue = Issue(
            severity: .error,
            category: .security,
            line: 42,
            message: "Test",
            recommendation: "Fix"
        )

        let data = try JSONEncoder().encode(issue)
        let decoded = try JSONDecoder().decode(Issue.self, from: data)

        #expect(decoded.severity == issue.severity)
        #expect(decoded.category == issue.category)
        #expect(decoded.line == issue.line)
        #expect(decoded.message == issue.message)
    }

    @Test("AnalysisResult round-trips through JSON encoding")
    func analysisResultCodable() throws {
        let result = AnalysisResult(
            file: "test.swift",
            language: .swift,
            issues: [Issue(severity: .error, category: .security, line: 1, message: "Test", recommendation: "Fix")],
            metrics: CodeMetrics(linesOfCode: 100)
        )

        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(AnalysisResult.self, from: data)

        #expect(decoded.file == result.file)
        #expect(decoded.language == result.language)
        #expect(decoded.issues.count == result.issues.count)
    }
}
