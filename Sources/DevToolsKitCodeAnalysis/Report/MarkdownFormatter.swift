import Foundation

/// Formats analysis results as Markdown.
///
/// > Since: 0.4.0
public struct MarkdownFormatter: Sendable {

    /// Format a single analysis result as Markdown.
    /// - Parameter result: The analysis result to format.
    /// - Returns: A Markdown-formatted string.
    public static func format(_ result: AnalysisResult) -> String {
        var output = ""

        output += "# Analysis Report\n\n"
        output += "**File:** `\(result.file)`  \n"
        output += "**Language:** \(result.language.displayName)  \n"
        output += "**Date:** \(formatDate(result.analyzedAt))  \n"
        output += "**Duration:** \(String(format: "%.3f", result.duration))s\n\n"

        output += "## Summary\n\n"
        output += "- **Issues:** \(result.summary)\n"
        output += "- **Quality Score:** \(result.score.grade) (\(Int(result.score.overall))/100) - \(result.score.rating)\n\n"

        output += "### Score Breakdown\n\n"
        output += "| Category | Score |\n"
        output += "|----------|-------|\n"
        output += "| Security | \(Int(result.score.security))/100 |\n"
        output += "| Performance | \(Int(result.score.performance))/100 |\n"
        output += "| Maintainability | \(Int(result.score.maintainability))/100 |\n"
        output += "| Style | \(Int(result.score.style))/100 |\n\n"

        if result.metrics.linesOfCode > 0 {
            output += "## Metrics\n\n"
            output += "| Metric | Value |\n"
            output += "|--------|-------|\n"
            output += "| Lines of Code | \(result.metrics.linesOfCode) |\n"
            output += "| Blank Lines | \(result.metrics.blankLines) |\n"
            output += "| Comment Lines | \(result.metrics.commentLines) |\n"
            output += "| Effective LOC | \(result.metrics.effectiveLinesOfCode) |\n"
            output += "| Cyclomatic Complexity | \(result.metrics.cyclomaticComplexity) (\(result.metrics.complexityRating)) |\n"
            output += "| Maintainability Index | \(String(format: "%.1f", result.metrics.maintainabilityIndex))/100 (\(result.metrics.maintainabilityRating)) |\n"
            if result.metrics.duplicationPercentage > 0 {
                output += "| Code Duplication | \(String(format: "%.1f", result.metrics.duplicationPercentage))% |\n"
            }
            output += "\n"
        }

        if !result.issues.isEmpty {
            output += "## Issues\n\n"

            let errorIssues = result.issues.filter { $0.severity == .error }
            let warningIssues = result.issues.filter { $0.severity == .warning }
            let infoIssues = result.issues.filter { $0.severity == .info }

            if !errorIssues.isEmpty {
                output += "### Errors (\(errorIssues.count))\n\n"
                output += formatIssuesTable(errorIssues)
            }

            if !warningIssues.isEmpty {
                output += "### Warnings (\(warningIssues.count))\n\n"
                output += formatIssuesTable(warningIssues)
            }

            if !infoIssues.isEmpty {
                output += "### Info (\(infoIssues.count))\n\n"
                output += formatIssuesTable(infoIssues)
            }
        } else {
            output += "## No Issues Found\n\nNo issues detected in this file.\n\n"
        }

        return output
    }

    /// Format a batch analysis result as Markdown.
    /// - Parameter batchResult: The batch result to format.
    /// - Returns: A Markdown-formatted string.
    public static func format(_ batchResult: BatchAnalysisResult) -> String {
        var output = ""

        output += "# Batch Analysis Report\n\n"
        output += "**Files Analyzed:** \(batchResult.results.count)  \n"
        output += "**Date:** \(formatDate(batchResult.analyzedAt))  \n"
        output += "**Duration:** \(String(format: "%.3f", batchResult.totalDuration))s\n\n"

        output += "## Summary\n\n"
        output += "- **Total Issues:** \(batchResult.summary)\n"
        output += "- **Average Score:** \(Int(batchResult.averageScore))/100\n\n"

        output += "## File Results\n\n"
        output += "| File | Issues | Score | Grade |\n"
        output += "|------|--------|-------|-------|\n"
        for result in batchResult.results {
            let fileName = URL(fileURLWithPath: result.file).lastPathComponent
            output += "| `\(fileName)` | \(result.errorCount)E, \(result.warningCount)W, \(result.infoCount)I | \(Int(result.score.overall))/100 | \(result.score.grade) |\n"
        }
        output += "\n"

        let allIssues = batchResult.results.flatMap { $0.issues }
        let byCategory = Dictionary(grouping: allIssues, by: { $0.category })

        if !byCategory.isEmpty {
            output += "## Issues by Category\n\n"
            output += "| Category | Count |\n"
            output += "|----------|-------|\n"
            for category in Category.allCases {
                if let issues = byCategory[category] {
                    output += "| \(category.displayName) | \(issues.count) |\n"
                }
            }
            output += "\n"
        }

        let criticalFiles = batchResult.results.filter { $0.hasErrors }
        if !criticalFiles.isEmpty {
            output += "## Critical Files\n\n"
            for result in criticalFiles {
                output += "### \(result.file)\n\n"
                let errors = result.issues.filter { $0.severity == .error }
                output += formatIssuesTable(errors)
            }
        }

        return output
    }

    // MARK: - Private Helpers

    private static func formatIssuesTable(_ issues: [Issue]) -> String {
        var output = ""

        for issue in issues {
            output += "#### Line \(issue.line)"
            if let code = issue.code {
                output += " [\(code)]"
            }
            if let cwe = issue.cwe {
                output += " (\(cwe))"
            }
            output += "\n\n"

            output += "**Category:** \(issue.category.displayName)  \n"
            output += "**Message:** \(issue.message)  \n"
            output += "**Recommendation:** \(issue.recommendation)\n\n"
        }

        return output
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
