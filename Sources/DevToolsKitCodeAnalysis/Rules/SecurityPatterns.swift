import Foundation

/// Pattern matcher for security rules against source file content.
///
/// > Since: 0.4.0
public struct SecurityPatterns: Sendable {

    /// Match a single security rule against a source file.
    /// - Parameters:
    ///   - rule: The security rule to match.
    ///   - file: The source file to scan.
    /// - Returns: Issues for each match found.
    public static func findMatches(for rule: SecurityRule, in file: SourceFile) -> [Issue] {
        var issues: [Issue] = []

        guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: [.caseInsensitive]) else {
            return issues
        }

        let lines = file.lines

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.hasPrefix("//") && !trimmed.hasPrefix("/*") && !trimmed.hasPrefix("*") else {
                continue
            }

            let nsLine = line as NSString
            let matches = regex.matches(
                in: line,
                options: [],
                range: NSRange(location: 0, length: nsLine.length)
            )

            for match in matches {
                issues.append(Issue(
                    severity: rule.severity,
                    category: .security,
                    line: lineNumber,
                    column: match.range.location,
                    message: rule.message,
                    recommendation: rule.recommendation,
                    code: rule.id,
                    cwe: rule.cwe
                ))
            }
        }

        return issues
    }

    /// Match multiple security rules against a source file.
    /// - Parameters:
    ///   - rules: The security rules to match.
    ///   - file: The source file to scan.
    /// - Returns: All issues found across all rules.
    public static func findMatches(for rules: [SecurityRule], in file: SourceFile) -> [Issue] {
        var allIssues: [Issue] = []

        for rule in rules {
            let issues = findMatches(for: rule, in: file)
            allIssues.append(contentsOf: issues)
        }

        return allIssues
    }

    /// Detect context-specific vulnerabilities that require multi-line analysis.
    /// - Parameter file: The source file to scan.
    /// - Returns: Issues for contextual vulnerabilities (code injection, redirects, weak random).
    public static func findContextualVulnerabilities(in file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines
        let content = file.content

        // Check for eval/exec patterns (code injection)
        if content.contains("eval(") || content.contains("exec(") {
            for (index, line) in lines.enumerated() {
                if line.contains("eval(") || line.contains("exec(") {
                    issues.append(Issue(
                        severity: .error,
                        category: .security,
                        line: index + 1,
                        message: "Dynamic code execution detected",
                        recommendation: "Avoid eval() and exec() functions as they can lead to code injection vulnerabilities.",
                        code: "SEC-026",
                        cwe: "CWE-95"
                    ))
                }
            }
        }

        // Check for unvalidated redirects
        for (index, line) in lines.enumerated() {
            if line.contains("redirect(") && line.contains("request") {
                issues.append(Issue(
                    severity: .warning,
                    category: .security,
                    line: index + 1,
                    message: "Potential unvalidated redirect",
                    recommendation: "Validate redirect URLs against a whitelist to prevent open redirect vulnerabilities.",
                    code: "SEC-027",
                    cwe: "CWE-601"
                ))
            }
        }

        // Check for weak random in security context
        if content.contains("arc4random") && (content.contains("token") || content.contains("session") || content.contains("key")) {
            for (index, line) in lines.enumerated() {
                if line.contains("arc4random") {
                    issues.append(Issue(
                        severity: .warning,
                        category: .security,
                        line: index + 1,
                        message: "Weak random number generator for security-sensitive operation",
                        recommendation: "Use SecRandomCopyBytes for generating cryptographic keys, tokens, or session IDs.",
                        code: "SEC-028",
                        cwe: "CWE-338"
                    ))
                    break
                }
            }
        }

        return issues
    }
}
