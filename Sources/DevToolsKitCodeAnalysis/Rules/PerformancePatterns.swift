import Foundation

/// A performance pattern definition.
///
/// > Since: 0.4.0
public struct PerformancePattern: Sendable {
    /// Unique pattern identifier (e.g. "PERF-001").
    public let id: String
    /// Description of the performance issue.
    public let description: String
    /// Severity level.
    public let severity: Severity
    /// Suggested remediation.
    public let recommendation: String

    /// Create a performance pattern.
    public init(id: String, description: String, severity: Severity, recommendation: String) {
        self.id = id
        self.description = description
        self.severity = severity
        self.recommendation = recommendation
    }
}

/// Performance analysis patterns and anti-pattern detectors.
///
/// > Since: 0.4.0
public struct PerformancePatterns: Sendable {

    /// All built-in performance patterns.
    public static let allPatterns: [PerformancePattern] = [
        PerformancePattern(
            id: "PERF-001",
            description: "Nested loops detected - O(n^2) or worse complexity",
            severity: .warning,
            recommendation: "Consider using more efficient algorithms or data structures. For lookups, use Set or Dictionary instead of nested loops."
        ),
        PerformancePattern(
            id: "PERF-002",
            description: "String concatenation in loop",
            severity: .warning,
            recommendation: "Use StringBuilder pattern or join() method. String concatenation in loops creates many intermediate objects."
        ),
        PerformancePattern(
            id: "PERF-003",
            description: "Array append in loop without capacity reservation",
            severity: .info,
            recommendation: "Use reserveCapacity() before appending in loops to avoid multiple reallocations."
        ),
        PerformancePattern(
            id: "PERF-004",
            description: "Potential N+1 query pattern",
            severity: .warning,
            recommendation: "Consider using batch operations or eager loading to avoid multiple database queries."
        ),
        PerformancePattern(
            id: "PERF-005",
            description: "Synchronous network call detected",
            severity: .error,
            recommendation: "Use async/await or completion handlers. Synchronous network calls block the thread and hurt responsiveness."
        ),
        PerformancePattern(
            id: "PERF-006",
            description: "Large array/collection literal",
            severity: .info,
            recommendation: "Consider lazy initialization or loading from file for large data structures."
        ),
        PerformancePattern(
            id: "PERF-007",
            description: "Inefficient contains() on Array in loop",
            severity: .warning,
            recommendation: "Convert to Set for O(1) lookups instead of O(n) for each contains() call."
        ),
        PerformancePattern(
            id: "PERF-008",
            description: "Creating Date() repeatedly in loop",
            severity: .warning,
            recommendation: "Create Date() once before the loop and reuse it."
        ),
        PerformancePattern(
            id: "PERF-009",
            description: "Force unwrapping in hot path",
            severity: .info,
            recommendation: "Consider using guard let or if let. Force unwraps add runtime overhead for trap checks."
        ),
        PerformancePattern(
            id: "PERF-010",
            description: "Inefficient filter().count pattern",
            severity: .info,
            recommendation: "Use contains(where:) or first(where:) != nil instead of filter().count for existence checks."
        ),
    ]

    /// Detect nested loops.
    /// - Parameter file: The source file to scan.
    /// - Returns: Issues for nested loop patterns.
    public static func detectNestedLoops(in file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines

        var loopDepth = 0
        var loopStartLines: [Int] = []

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.hasPrefix("//") else { continue }

            if trimmed.hasPrefix("for ") || trimmed.hasPrefix("while ") ||
                trimmed.contains("forEach") {
                loopDepth += 1
                loopStartLines.append(lineNumber)

                if loopDepth > 1 {
                    let recommendation = allPatterns.first { $0.id == "PERF-001" }?.recommendation
                        ?? "Consider using more efficient algorithms or data structures."
                    issues.append(Issue(
                        severity: .warning,
                        category: .performance,
                        line: lineNumber,
                        message: "Nested loop detected (depth \(loopDepth)) - O(n^2) or worse",
                        recommendation: recommendation,
                        code: "PERF-001"
                    ))
                }
            }

            if trimmed == "}" && !loopStartLines.isEmpty {
                loopDepth = max(0, loopDepth - 1)
                if !loopStartLines.isEmpty {
                    loopStartLines.removeLast()
                }
            }
        }

        return issues
    }

    /// Detect string concatenation in loops.
    /// - Parameter file: The source file to scan.
    /// - Returns: Issues for string concatenation inside loop bodies.
    public static func detectStringConcatInLoop(in file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines

        var inLoop = false
        var braceDepth = 0

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.hasPrefix("//") else { continue }

            if trimmed.hasPrefix("for ") || trimmed.hasPrefix("while ") {
                inLoop = true
                braceDepth = 0
            }

            if inLoop {
                braceDepth += trimmed.filter { $0 == "{" }.count
                braceDepth -= trimmed.filter { $0 == "}" }.count

                if (trimmed.contains("+=") && (trimmed.contains("\"") || trimmed.contains("String"))) ||
                    (trimmed.contains(" + ") && trimmed.contains("\"")) {
                    let recommendation = allPatterns.first { $0.id == "PERF-002" }?.recommendation
                        ?? "Use StringBuilder pattern or join() method."
                    issues.append(Issue(
                        severity: .warning,
                        category: .performance,
                        line: lineNumber,
                        message: "String concatenation in loop",
                        recommendation: recommendation,
                        code: "PERF-002"
                    ))
                }

                if braceDepth == 0 {
                    inLoop = false
                }
            }
        }

        return issues
    }

    /// Detect array append in loops without prior capacity reservation.
    /// - Parameter file: The source file to scan.
    /// - Returns: Issues for array appends in loops without reserveCapacity.
    public static func detectArrayAppendWithoutCapacity(in file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines

        var inLoop = false
        var braceDepth = 0
        var hasReserveCapacity = false

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.hasPrefix("//") else { continue }

            if trimmed.hasPrefix("for ") || trimmed.hasPrefix("while ") {
                inLoop = true
                braceDepth = 0
                hasReserveCapacity = false
            }

            if inLoop {
                braceDepth += trimmed.filter { $0 == "{" }.count
                braceDepth -= trimmed.filter { $0 == "}" }.count

                if trimmed.contains("reserveCapacity") {
                    hasReserveCapacity = true
                }

                if !hasReserveCapacity && trimmed.contains(".append(") {
                    let recommendation = allPatterns.first { $0.id == "PERF-003" }?.recommendation
                        ?? "Use reserveCapacity() before appending in loops."
                    issues.append(Issue(
                        severity: .info,
                        category: .performance,
                        line: lineNumber,
                        message: "Array append in loop without capacity reservation",
                        recommendation: recommendation,
                        code: "PERF-003"
                    ))
                    hasReserveCapacity = true
                }

                if braceDepth == 0 {
                    inLoop = false
                }
            }
        }

        return issues
    }

    /// Detect potentially synchronous network calls.
    /// - Parameter file: The source file to scan.
    /// - Returns: Issues for synchronous-looking network call patterns.
    public static func detectSyncNetworkCalls(in file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines

        let syncPatterns = [
            "URLSession.shared.dataTask",
            "URLSession.shared.uploadTask",
            "URLSession.shared.downloadTask",
        ]

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.hasPrefix("//") else { continue }

            for pattern in syncPatterns {
                if trimmed.contains(pattern) && !trimmed.contains("async") && !trimmed.contains("completion") {
                    let recommendation = allPatterns.first { $0.id == "PERF-005" }?.recommendation
                        ?? "Use async/await or completion handlers."
                    issues.append(Issue(
                        severity: .error,
                        category: .performance,
                        line: lineNumber,
                        message: "Potentially synchronous network call",
                        recommendation: recommendation,
                        code: "PERF-005"
                    ))
                }
            }
        }

        return issues
    }

    /// Detect inefficient `contains()` on Array inside loops.
    /// - Parameter file: The source file to scan.
    /// - Returns: Issues for Array.contains() used in loop bodies.
    public static func detectArrayContainsInLoop(in file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines

        var inLoop = false
        var braceDepth = 0

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.hasPrefix("//") else { continue }

            if trimmed.hasPrefix("for ") || trimmed.hasPrefix("while ") {
                inLoop = true
                braceDepth = 0
            }

            if inLoop {
                braceDepth += trimmed.filter { $0 == "{" }.count
                braceDepth -= trimmed.filter { $0 == "}" }.count

                if trimmed.contains(".contains(") && !trimmed.contains("Set") {
                    let recommendation = allPatterns.first { $0.id == "PERF-007" }?.recommendation
                        ?? "Convert to Set for O(1) lookups."
                    issues.append(Issue(
                        severity: .warning,
                        category: .performance,
                        line: lineNumber,
                        message: "Array contains() in loop - O(n) per iteration",
                        recommendation: recommendation,
                        code: "PERF-007"
                    ))
                }

                if braceDepth == 0 {
                    inLoop = false
                }
            }
        }

        return issues
    }

    /// Detect inefficient `filter().count` pattern.
    /// - Parameter file: The source file to scan.
    /// - Returns: Issues for filter-then-count patterns.
    public static func detectFilterCount(in file: SourceFile) -> [Issue] {
        var issues: [Issue] = []
        let lines = file.lines

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.hasPrefix("//") else { continue }

            if trimmed.contains(".filter") && (trimmed.contains(".count") || trimmed.contains("> 0")) {
                let recommendation = allPatterns.first { $0.id == "PERF-010" }?.recommendation
                    ?? "Use contains(where:) or first(where:) != nil."
                issues.append(Issue(
                    severity: .info,
                    category: .performance,
                    line: lineNumber,
                    message: "Inefficient filter().count pattern",
                    recommendation: recommendation,
                    code: "PERF-010"
                ))
            }
        }

        return issues
    }
}
