import Foundation

/// Detects code smells and anti-patterns such as long methods,
/// large types, unused variables, magic numbers, and long parameter lists.
///
/// > Since: 0.4.0
public struct CodeSmellDetector: Sendable {

    /// Detect long methods (>50 lines).
    /// - Parameter file: The source file to analyze.
    /// - Returns: Issues for methods exceeding the line threshold.
    public static func detectLongMethods(_ file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines

        var currentFunction: MethodInfo?
        var braceDepth = 0

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if isFunctionDeclaration(trimmed) {
                currentFunction = MethodInfo(
                    name: extractFunctionName(from: trimmed),
                    startLine: lineNumber,
                    endLine: lineNumber
                )
            }

            if currentFunction != nil {
                braceDepth += trimmed.filter { $0 == "{" }.count
                braceDepth -= trimmed.filter { $0 == "}" }.count
                currentFunction?.endLine = lineNumber

                if braceDepth == 0 {
                    if let method = currentFunction {
                        let lineCount = method.endLine - method.startLine + 1

                        if lineCount > 50 {
                            issues.append(Issue(
                                severity: lineCount > 100 ? .error : .warning,
                                category: .complexity,
                                line: method.startLine,
                                message: "Long method '\(method.name)' (\(lineCount) lines)",
                                recommendation: "Consider breaking this method into smaller, focused functions. Aim for methods under 50 lines."
                            ))
                        }
                    }
                    currentFunction = nil
                }
            }
        }

        return issues
    }

    /// Detect large classes/structs (>300 lines).
    /// - Parameter file: The source file to analyze.
    /// - Returns: Issues for types exceeding the line threshold.
    public static func detectLargeTypes(_ file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines

        var currentType: TypeInfo?
        var braceDepth = 0

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if isTypeDeclaration(trimmed) {
                currentType = TypeInfo(
                    name: extractTypeName(from: trimmed),
                    startLine: lineNumber,
                    endLine: lineNumber
                )
            }

            if currentType != nil {
                braceDepth += trimmed.filter { $0 == "{" }.count
                braceDepth -= trimmed.filter { $0 == "}" }.count
                currentType?.endLine = lineNumber

                if braceDepth == 0 {
                    if let type = currentType {
                        let lineCount = type.endLine - type.startLine + 1

                        if lineCount > 300 {
                            issues.append(Issue(
                                severity: lineCount > 500 ? .error : .warning,
                                category: .complexity,
                                line: type.startLine,
                                message: "Large type '\(type.name)' (\(lineCount) lines)",
                                recommendation: "Consider breaking this type into smaller, more focused components. Aim for types under 300 lines."
                            ))
                        }
                    }
                    currentType = nil
                }
            }
        }

        return issues
    }

    /// Detect potentially unused variables (basic heuristic).
    /// - Parameter file: The source file to analyze.
    /// - Returns: Issues for variables that appear only once in the file.
    public static func detectUnusedVariables(_ file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines
        let content = file.content

        guard let variablePattern = try? NSRegularExpression(
            pattern: #"(?:let|var)\s+(\w+)\s*[:=]"#,
            options: []
        ) else {
            return issues
        }

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.hasPrefix("//") else { continue }

            let nsLine = line as NSString
            let matches = variablePattern.matches(
                in: line,
                options: [],
                range: NSRange(location: 0, length: nsLine.length)
            )

            for match in matches {
                if match.numberOfRanges > 1 {
                    let variableName = nsLine.substring(with: match.range(at: 1))

                    guard variableName != "_" && !variableName.hasPrefix("_") else { continue }

                    let usageCount = content.components(separatedBy: variableName).count - 1

                    if usageCount == 1 {
                        issues.append(Issue(
                            severity: .info,
                            category: .style,
                            line: lineNumber,
                            message: "Variable '\(variableName)' may be unused",
                            recommendation: "Remove unused variables or prefix with _ if intentionally unused."
                        ))
                    }
                }
            }
        }

        return issues
    }

    /// Detect magic numbers (hardcoded numeric literals of 2+ digits).
    /// - Parameter file: The source file to analyze.
    /// - Returns: Issues for magic numbers found outside variable declarations.
    public static func detectMagicNumbers(_ file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines

        guard let numberPattern = try? NSRegularExpression(
            pattern: #"\b(?![01]\b|2\b|-1\b)\d{2,}\b"#,
            options: []
        ) else {
            return issues
        }

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.hasPrefix("//") else { continue }
            guard !trimmed.contains("let ") && !trimmed.contains("var ") else { continue }

            let nsLine = line as NSString
            let matches = numberPattern.matches(
                in: line,
                options: [],
                range: NSRange(location: 0, length: nsLine.length)
            )

            if !matches.isEmpty {
                issues.append(Issue(
                    severity: .info,
                    category: .style,
                    line: lineNumber,
                    message: "Magic number detected",
                    recommendation: "Consider extracting numeric literals into named constants for better maintainability."
                ))
            }
        }

        return issues
    }

    /// Detect functions with too many parameters (>5).
    /// - Parameter file: The source file to analyze.
    /// - Returns: Issues for functions with long parameter lists.
    public static func detectLongParameterLists(_ file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard isFunctionDeclaration(trimmed) else { continue }

            if let startParen = trimmed.firstIndex(of: "("),
               let endParen = trimmed.lastIndex(of: ")") {
                let params = String(trimmed[startParen...endParen])
                let paramCount = params.components(separatedBy: ",").count

                if paramCount > 5 {
                    let funcName = extractFunctionName(from: trimmed)
                    issues.append(Issue(
                        severity: .warning,
                        category: .complexity,
                        line: lineNumber,
                        message: "Function '\(funcName)' has too many parameters (\(paramCount))",
                        recommendation: "Consider grouping related parameters into a configuration object or breaking the function into smaller pieces."
                    ))
                }
            }
        }

        return issues
    }

    // MARK: - Helper Methods

    private static func isFunctionDeclaration(_ line: String) -> Bool {
        line.contains("func ") || line.contains("init(") || line.contains("init ")
    }

    private static func isTypeDeclaration(_ line: String) -> Bool {
        let patterns = ["class ", "struct ", "enum ", "protocol ", "actor "]
        return patterns.contains { line.contains($0) && !line.hasPrefix("//") }
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

    private static func extractTypeName(from line: String) -> String {
        let patterns = ["class ", "struct ", "enum ", "protocol ", "actor "]

        for pattern in patterns {
            if let range = line.range(of: pattern) {
                let afterKeyword = line[range.upperBound...]
                let components = afterKeyword.components(separatedBy: CharacterSet(charactersIn: " :{<"))
                if let name = components.first, !name.isEmpty {
                    return name
                }
            }
        }

        return "unknown"
    }
}

// MARK: - Supporting Types

private struct MethodInfo: Sendable {
    let name: String
    let startLine: Int
    var endLine: Int
}

private struct TypeInfo: Sendable {
    let name: String
    let startLine: Int
    var endLine: Int
}
