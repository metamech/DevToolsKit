import Foundation

/// Formats analysis results for console output.
///
/// > Since: 0.4.0
public struct ConsoleFormatter: Sendable {

    /// Format a single analysis result for console display.
    /// - Parameter result: The analysis result to format.
    /// - Returns: A decorated console-friendly string.
    public static func format(_ result: AnalysisResult) -> String {
        var output = ""

        output += "===================================================================\n"
        output += "  Analysis Report: \(result.file)\n"
        output += "===================================================================\n\n"

        output += "Summary\n"
        output += "  Language: \(result.language.displayName)\n"
        output += "  Issues: \(result.summary)\n"
        output += "  Quality Score: \(result.score.grade) (\(Int(result.score.overall))/100) - \(result.score.rating)\n"
        output += "  Duration: \(String(format: "%.3f", result.duration))s\n\n"

        if result.metrics.linesOfCode > 0 {
            output += "Metrics\n"
            output += "  Lines of Code: \(result.metrics.linesOfCode)\n"
            output += "  Blank Lines: \(result.metrics.blankLines)\n"
            output += "  Comment Lines: \(result.metrics.commentLines)\n"
            output += "  Effective LOC: \(result.metrics.effectiveLinesOfCode)\n"
            output += "  Cyclomatic Complexity: \(result.metrics.cyclomaticComplexity) (\(result.metrics.complexityRating))\n"
            output += "  Maintainability: \(String(format: "%.1f", result.metrics.maintainabilityIndex))/100 (\(result.metrics.maintainabilityRating))\n"
            if result.metrics.duplicationPercentage > 0 {
                output += "  Duplication: \(String(format: "%.1f", result.metrics.duplicationPercentage))%\n"
            }
            output += "\n"
        }

        output += "Score Breakdown\n"
        output += "  Security: \(Int(result.score.security))/100\n"
        output += "  Performance: \(Int(result.score.performance))/100\n"
        output += "  Maintainability: \(Int(result.score.maintainability))/100\n"
        output += "  Style: \(Int(result.score.style))/100\n\n"

        if !result.issues.isEmpty {
            output += "Issues Found\n\n"

            let errorIssues = result.issues.filter { $0.severity == .error }
            let warningIssues = result.issues.filter { $0.severity == .warning }
            let infoIssues = result.issues.filter { $0.severity == .info }

            if !errorIssues.isEmpty {
                output += formatIssueSection("Errors", issues: errorIssues)
            }

            if !warningIssues.isEmpty {
                output += formatIssueSection("Warnings", issues: warningIssues)
            }

            if !infoIssues.isEmpty {
                output += formatIssueSection("Info", issues: infoIssues)
            }
        } else {
            output += "No issues found.\n\n"
        }

        output += "===================================================================\n"

        return output
    }

    /// Format a batch analysis result for console display.
    /// - Parameter batchResult: The batch result to format.
    /// - Returns: A decorated console-friendly string.
    public static func format(_ batchResult: BatchAnalysisResult) -> String {
        var output = ""

        output += "===================================================================\n"
        output += "  Batch Analysis Report\n"
        output += "===================================================================\n\n"

        output += "Overall Summary\n"
        output += "  Files Analyzed: \(batchResult.results.count)\n"
        output += "  Total Issues: \(batchResult.summary)\n"
        output += "  Average Score: \(Int(batchResult.averageScore))/100\n"
        output += "  Total Duration: \(String(format: "%.3f", batchResult.totalDuration))s\n\n"

        output += "File Results\n\n"
        for result in batchResult.results {
            output += "  \(result.file)\n"
            output += "    Issues: \(result.summary)\n"
            output += "    Score: \(result.score.grade) (\(Int(result.score.overall))/100)\n"
            output += "\n"
        }

        let allIssues = batchResult.results.flatMap { $0.issues }
        let byCategory = Dictionary(grouping: allIssues, by: { $0.category })

        if !byCategory.isEmpty {
            output += "Issues by Category\n"
            for category in Category.allCases {
                if let issues = byCategory[category] {
                    output += "  \(category.displayName): \(issues.count)\n"
                }
            }
            output += "\n"
        }

        output += "===================================================================\n"

        return output
    }

    // MARK: - Private Helpers

    private static func formatIssueSection(_ title: String, issues: [Issue]) -> String {
        var output = "\(title) (\(issues.count))\n"
        output += String(repeating: "-", count: 63) + "\n"

        for issue in issues {
            output += formatIssue(issue)
        }

        output += "\n"
        return output
    }

    private static func formatIssue(_ issue: Issue) -> String {
        var output = ""

        output += "  Line \(issue.line)"
        if let column = issue.column {
            output += ":\(column)"
        }
        output += " - "

        if let code = issue.code {
            output += "[\(code)] "
        }
        output += "[\(issue.category.displayName)] "

        output += "\(issue.message)\n"

        if let cwe = issue.cwe {
            output += "    (\(cwe))\n"
        }

        output += "    Suggestion: \(issue.recommendation)\n\n"

        return output
    }
}
