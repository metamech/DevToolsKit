import Foundation

/// Analyzes code complexity including cyclomatic complexity and nesting depth.
///
/// > Since: 0.4.0
public struct ComplexityAnalyzer: Sendable {

    /// Analyze cyclomatic complexity per function in a source file.
    /// - Parameter file: The source file to analyze.
    /// - Returns: Issues for functions exceeding the complexity threshold (>10).
    public static func analyzeCyclomaticComplexity(_ file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines

        var currentFunction: FunctionInfo?
        var braceDepth = 0

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if isFunctionDeclaration(trimmed) {
                if let prevFunc = currentFunction, prevFunc.complexity > 10 {
                    issues.append(Issue(
                        severity: prevFunc.complexity > 20 ? .error : .warning,
                        category: .complexity,
                        line: prevFunc.startLine,
                        message: "Function '\(prevFunc.name)' has high cyclomatic complexity (\(prevFunc.complexity))",
                        recommendation: "Consider breaking down this function into smaller, more manageable pieces. Aim for complexity < 10."
                    ))
                }

                currentFunction = FunctionInfo(
                    name: extractFunctionName(from: trimmed),
                    startLine: lineNumber,
                    complexity: 1
                )
            }

            if currentFunction != nil {
                let decisionPoints = countDecisionPoints(in: trimmed)
                currentFunction?.complexity += decisionPoints
            }

            braceDepth += trimmed.filter { $0 == "{" }.count
            braceDepth -= trimmed.filter { $0 == "}" }.count

            if braceDepth == 0 && currentFunction != nil {
                if let funcInfo = currentFunction, funcInfo.complexity > 10 {
                    issues.append(Issue(
                        severity: funcInfo.complexity > 20 ? .error : .warning,
                        category: .complexity,
                        line: funcInfo.startLine,
                        message: "Function '\(funcInfo.name)' has high cyclomatic complexity (\(funcInfo.complexity))",
                        recommendation: "Consider breaking down this function into smaller, more manageable pieces. Aim for complexity < 10."
                    ))
                }
                currentFunction = nil
            }
        }

        return issues
    }

    /// Calculate total cyclomatic complexity for the entire file.
    /// - Parameter file: The source file to analyze.
    /// - Returns: The total cyclomatic complexity score.
    public static func calculateTotalComplexity(_ file: SourceFile) -> Int {
        var complexity = 1

        for line in file.lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            complexity += countDecisionPoints(in: trimmed)
        }

        return complexity
    }

    // MARK: - Helper Methods

    private static func isFunctionDeclaration(_ line: String) -> Bool {
        let patterns = [
            "func ",
            "init(",
            "init ",
        ]

        for pattern in patterns {
            if line.contains(pattern) && !line.hasPrefix("//") {
                return true
            }
        }

        return false
    }

    private static func extractFunctionName(from line: String) -> String {
        if line.contains("init") {
            return "init"
        }

        if let range = line.range(of: "func ") {
            let afterFunc = line[range.upperBound...]
            if let parenRange = afterFunc.range(of: "(") {
                return String(afterFunc[..<parenRange.lowerBound])
            }
        }

        return "unknown"
    }

    private static func countDecisionPoints(in line: String) -> Int {
        guard !line.hasPrefix("//") else { return 0 }

        var count = 0

        let keywords = [
            "if ", "else if", "else",
            "for ", "while ", "repeat",
            "case ",
            "guard ",
            "catch ",
            "&&", "||",
            "?",
        ]

        for keyword in keywords {
            if keyword == "?" {
                let questionMarks = line.components(separatedBy: "?").count - 1
                let optionalTypes = line.components(separatedBy: "?:").count - 1
                count += max(0, questionMarks - optionalTypes)
            } else {
                let occurrences = line.components(separatedBy: keyword).count - 1
                count += occurrences
            }
        }

        return count
    }

    /// Detect deeply nested code blocks (indentation > 4 levels).
    /// - Parameter file: The source file to analyze.
    /// - Returns: Issues for lines with excessive nesting depth.
    public static func analyzeNesting(_ file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let indentLevel = countIndentation(line)

            if indentLevel > 4 {
                issues.append(Issue(
                    severity: .warning,
                    category: .complexity,
                    line: lineNumber,
                    message: "Deep nesting detected (level \(indentLevel))",
                    recommendation: "Consider extracting nested logic into separate functions to improve readability."
                ))
            }
        }

        return issues
    }

    private static func countIndentation(_ line: String) -> Int {
        var count = 0
        for char in line {
            if char == " " {
                count += 1
            } else if char == "\t" {
                count += 4
            } else {
                break
            }
        }
        return count / 4
    }
}

// MARK: - Supporting Types

private struct FunctionInfo: Sendable {
    let name: String
    let startLine: Int
    var complexity: Int
}
