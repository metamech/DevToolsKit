import Foundation
import DevToolsKitCodeAnalysis

/// Swift-specific code analysis rules.
///
/// Provides detection for common Swift anti-patterns and style issues
/// including force unwraps, implicitly unwrapped optionals, retain cycles,
/// empty catch blocks, print statements, TODO/FIXME comments, and forced type casts.
///
/// > Since: 0.4.0
public struct SwiftSpecificRules: Sendable {

    /// Detect force unwraps (`!`) which can cause runtime crashes.
    ///
    /// - Parameter file: The source file to analyze.
    /// - Returns: Issues for each force unwrap found.
    public static func detectForceUnwraps(_ file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines

        guard let forceUnwrapPattern = try? NSRegularExpression(
            pattern: #"[a-zA-Z0-9_\)]\s*!\s*(?![=:])"#
        ) else { return issues }

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.hasPrefix("//") else { continue }
            guard !trimmed.contains("import ") else { continue }

            let nsLine = line as NSString
            let matches = forceUnwrapPattern.matches(
                in: line,
                range: NSRange(location: 0, length: nsLine.length)
            )

            for match in matches {
                issues.append(Issue(
                    severity: .warning,
                    category: .style,
                    line: lineNumber,
                    column: match.range.location,
                    message: "Force unwrap (!) detected",
                    recommendation: "Use optional binding (if let, guard let) or optional chaining (?.) instead of force unwrapping to avoid potential runtime crashes.",
                    code: "SWIFT-001"
                ))
            }
        }

        return issues
    }

    /// Detect implicitly unwrapped optionals (`!`) in declarations.
    ///
    /// - Parameter file: The source file to analyze.
    /// - Returns: Issues for each IUO declaration found.
    public static func detectImplicitlyUnwrappedOptionals(_ file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines

        guard let iuoPattern = try? NSRegularExpression(
            pattern: #"(?:var|let)\s+\w+\s*:\s*\w+\s*!"#
        ) else { return issues }

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.hasPrefix("//") else { continue }

            let nsLine = line as NSString
            let matches = iuoPattern.matches(
                in: line,
                range: NSRange(location: 0, length: nsLine.length)
            )

            for _ in matches {
                issues.append(Issue(
                    severity: .info,
                    category: .style,
                    line: lineNumber,
                    message: "Implicitly unwrapped optional detected",
                    recommendation: "Consider using regular optional (Type?) and proper unwrapping unless there's a specific reason for IUO (e.g., IBOutlets).",
                    code: "SWIFT-002"
                ))
            }
        }

        return issues
    }

    /// Detect potential retain cycles in closures that capture `self` without `[weak self]`.
    ///
    /// - Parameter file: The source file to analyze.
    /// - Returns: Issues for each potential retain cycle found.
    public static func detectPotentialRetainCycles(_ file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines

        var inClosure = false
        var closureStartLine = 0
        var hasWeakSelf = false
        var usesSelf = false

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("{") && (trimmed.contains(" in") || line.contains("{ [")) {
                inClosure = true
                closureStartLine = lineNumber
                hasWeakSelf = trimmed.contains("[weak self]") || trimmed.contains("[unowned self]")
                usesSelf = false
            }

            if inClosure {
                if trimmed.contains("self.") || trimmed.contains("self?.") {
                    usesSelf = true
                }

                if trimmed.contains("}") {
                    if usesSelf && !hasWeakSelf {
                        issues.append(Issue(
                            severity: .warning,
                            category: .style,
                            line: closureStartLine,
                            message: "Potential retain cycle: closure captures 'self' strongly",
                            recommendation: "Use [weak self] or [unowned self] capture list to avoid retain cycles.",
                            code: "SWIFT-003"
                        ))
                    }
                    inClosure = false
                }
            }
        }

        return issues
    }

    /// Detect empty catch blocks that silently swallow errors.
    ///
    /// - Parameter file: The source file to analyze.
    /// - Returns: Issues for each empty catch block found.
    public static func detectEmptyCatchBlocks(_ file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines

        var catchLineNumber: Int?
        var afterCatch = false

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("catch") || trimmed.contains("} catch") {
                catchLineNumber = lineNumber
                afterCatch = true
                continue
            }

            if afterCatch {
                if trimmed == "}" {
                    if let catchLine = catchLineNumber {
                        issues.append(Issue(
                            severity: .warning,
                            category: .style,
                            line: catchLine,
                            message: "Empty catch block",
                            recommendation: "Handle errors properly or at minimum log them. Silently ignoring errors can hide bugs.",
                            code: "SWIFT-004"
                        ))
                    }
                    afterCatch = false
                } else if !trimmed.isEmpty {
                    afterCatch = false
                }
            }
        }

        return issues
    }

    /// Detect `print()` statements that should use proper logging in production.
    ///
    /// - Parameter file: The source file to analyze.
    /// - Returns: Issues for each print statement found.
    public static func detectPrintStatements(_ file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.hasPrefix("//") else { continue }

            if trimmed.contains("print(") || trimmed.hasPrefix("print(") {
                issues.append(Issue(
                    severity: .info,
                    category: .style,
                    line: lineNumber,
                    message: "Print statement detected",
                    recommendation: "Consider using a proper logging framework (e.g., OSLog, SwiftLog) instead of print() for production code.",
                    code: "SWIFT-005"
                ))
            }
        }

        return issues
    }

    /// Detect TODO and FIXME comments.
    ///
    /// - Parameter file: The source file to analyze.
    /// - Returns: Issues for each TODO/FIXME comment found.
    public static func detectTODOComments(_ file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("TODO:") || trimmed.contains("TODO ") {
                issues.append(Issue(
                    severity: .info,
                    category: .style,
                    line: lineNumber,
                    message: "TODO comment found",
                    recommendation: "Address TODO items before shipping to production."
                ))
            }

            if trimmed.contains("FIXME:") || trimmed.contains("FIXME ") {
                issues.append(Issue(
                    severity: .warning,
                    category: .style,
                    line: lineNumber,
                    message: "FIXME comment found",
                    recommendation: "Address FIXME items - they typically indicate known issues that need attention."
                ))
            }
        }

        return issues
    }

    /// Detect forced type casting (`as!`) which can cause runtime crashes.
    ///
    /// - Parameter file: The source file to analyze.
    /// - Returns: Issues for each forced cast found.
    public static func detectForcedTypeCasting(_ file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.hasPrefix("//") else { continue }

            if trimmed.contains(" as!") {
                issues.append(Issue(
                    severity: .warning,
                    category: .style,
                    line: lineNumber,
                    message: "Forced type cast (as!) detected",
                    recommendation: "Use optional type casting (as?) with proper error handling instead of forced casting to avoid runtime crashes.",
                    code: "SWIFT-006"
                ))
            }
        }

        return issues
    }
}
