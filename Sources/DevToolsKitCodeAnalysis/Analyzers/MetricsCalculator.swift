import Foundation

/// Calculates code quality metrics for source files.
///
/// Computes line counts, cyclomatic complexity, maintainability index,
/// and code duplication percentage.
///
/// ```swift
/// let metrics = MetricsCalculator.calculate(for: file)
/// print(metrics.complexityRating) // "Simple"
/// ```
///
/// > Since: 0.4.0
public struct MetricsCalculator: Sendable {

    /// Calculate comprehensive metrics for a source file.
    /// - Parameter file: The source file to analyze.
    /// - Returns: A ``CodeMetrics`` value with computed metrics.
    public static func calculate(for file: SourceFile) -> CodeMetrics {
        let lines = file.lines

        var linesOfCode = 0
        var blankLines = 0
        var commentLines = 0

        var inMultiLineComment = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("/*") {
                inMultiLineComment = true
            }

            if inMultiLineComment {
                commentLines += 1
                if trimmed.contains("*/") {
                    inMultiLineComment = false
                }
                continue
            }

            if trimmed.isEmpty {
                blankLines += 1
            } else if trimmed.hasPrefix("//") || trimmed.hasPrefix("*") {
                commentLines += 1
            } else {
                linesOfCode += 1
            }
        }

        let cyclomaticComplexity = calculateCyclomaticComplexity(for: file)

        let maintainabilityIndex = calculateMaintainabilityIndex(
            linesOfCode: linesOfCode,
            cyclomaticComplexity: cyclomaticComplexity
        )

        let duplicationPercentage = calculateDuplication(for: file)

        return CodeMetrics(
            linesOfCode: linesOfCode,
            blankLines: blankLines,
            commentLines: commentLines,
            cyclomaticComplexity: cyclomaticComplexity,
            maintainabilityIndex: maintainabilityIndex,
            duplicationPercentage: duplicationPercentage
        )
    }

    /// Calculate cyclomatic complexity for a source file.
    private static func calculateCyclomaticComplexity(for file: SourceFile) -> Int {
        var complexity = 1
        let content = file.content

        let decisionKeywords = [
            "if ", "else if", "else",
            "for ", "while ", "repeat",
            "case ", "default:",
            "guard ", "catch ",
            "&&", "||", "?",
        ]

        for keyword in decisionKeywords {
            let count = content.components(separatedBy: keyword).count - 1
            complexity += count
        }

        return complexity
    }

    /// Calculate maintainability index.
    ///
    /// Simplified MI formula based on cyclomatic complexity and lines of code.
    private static func calculateMaintainabilityIndex(linesOfCode: Int, cyclomaticComplexity: Int) -> Double {
        let loc = Double(max(1, linesOfCode))
        let complexity = Double(max(1, cyclomaticComplexity))

        let avgComplexity = complexity / loc * 100
        let mi = max(0, min(100, 171 - 5.2 * log(avgComplexity) - 0.23 * avgComplexity - 16.2 * log(loc)))

        return mi
    }

    /// Calculate code duplication percentage (basic implementation).
    private static func calculateDuplication(for file: SourceFile) -> Double {
        let lines = file.lines
        var duplicateLines = 0
        var seenLines = Set<String>()

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.isEmpty && !trimmed.hasPrefix("//") && !trimmed.hasPrefix("/*") else {
                continue
            }

            guard trimmed.count > 5 else {
                continue
            }

            if seenLines.contains(trimmed) {
                duplicateLines += 1
            } else {
                seenLines.insert(trimmed)
            }
        }

        let totalSignificantLines = Double(max(1, seenLines.count + duplicateLines))
        return (Double(duplicateLines) / totalSignificantLines) * 100
    }

    /// Calculate a detailed metrics summary.
    /// - Parameter metrics: The code metrics to summarize.
    /// - Returns: A ``MetricsSummary`` with derived values.
    public static func summary(for metrics: CodeMetrics) -> MetricsSummary {
        return MetricsSummary(
            totalLines: metrics.linesOfCode + metrics.blankLines + metrics.commentLines,
            effectiveLOC: metrics.effectiveLinesOfCode,
            commentRatio: calculateCommentRatio(metrics),
            complexityRating: metrics.complexityRating,
            maintainabilityRating: metrics.maintainabilityRating,
            duplicationPercentage: metrics.duplicationPercentage
        )
    }

    private static func calculateCommentRatio(_ metrics: CodeMetrics) -> Double {
        let total = Double(metrics.linesOfCode + metrics.commentLines)
        guard total > 0 else { return 0 }
        return (Double(metrics.commentLines) / total) * 100
    }
}

// MARK: - Supporting Types

/// Detailed metrics summary with derived values.
///
/// > Since: 0.4.0
public struct MetricsSummary: Sendable {
    /// Total line count (code + blank + comment).
    public let totalLines: Int
    /// Effective lines of code (excluding blanks and comments).
    public let effectiveLOC: Int
    /// Percentage of lines that are comments.
    public let commentRatio: Double
    /// Human-readable complexity rating.
    public let complexityRating: String
    /// Human-readable maintainability rating.
    public let maintainabilityRating: String
    /// Percentage of duplicated lines.
    public let duplicationPercentage: Double

    /// Multi-line summary string.
    public var summary: String {
        """
        Lines: \(totalLines) total, \(effectiveLOC) effective
        Comments: \(String(format: "%.1f", commentRatio))%
        Complexity: \(complexityRating)
        Maintainability: \(maintainabilityRating)
        Duplication: \(String(format: "%.1f", duplicationPercentage))%
        """
    }
}
