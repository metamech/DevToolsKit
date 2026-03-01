[< Guide](GUIDE.md) | [Index](../INDEX.md)

# DevToolsKitCodeAnalysis API Reference

> Source: `Sources/DevToolsKitCodeAnalysis/`
> Since: 0.4.0

## Core Types

### `CodeAnalyzer` (Protocol)

```swift
public protocol CodeAnalyzer: Sendable {
    func analyze(_ file: SourceFile) async throws -> AnalysisResult
}
```

### `SourceFile`

```swift
public struct SourceFile: Sendable {
    public let path: String
    public let content: String
    public let language: ProgrammingLanguage

    public init(path: String, content: String, language: ProgrammingLanguage? = nil)
    public static func load(from url: URL) throws -> SourceFile

    public var lines: [String]
    public var lineCount: Int
    public func line(at index: Int) -> String?
    public func lines(in range: Range<Int>) -> [String]
    public func context(around line: Int, contextLines: Int = 2) -> [String]
}
```

### `ProgrammingLanguage`

```swift
public enum ProgrammingLanguage: String, CaseIterable, Codable, Sendable {
    case swift, python, javascript, typescript, go, rust, c, cpp,
         java, kotlin, ruby, php, html, css, markdown, json, yaml,
         xml, shell, unknown

    public var displayName: String
}
```

### `Severity`

```swift
public enum Severity: String, Codable, Sendable, CaseIterable {
    case error, warning, info
    public var displayName: String
    public var priority: Int
}
```

### `Category`

```swift
public enum Category: String, Codable, CaseIterable, Sendable {
    case security, performance, style, complexity, duplication
    public var displayName: String
    public var description: String
}
```

### `Issue`

```swift
public struct Issue: Codable, Sendable, Identifiable {
    public let id: UUID
    public let severity: Severity
    public let category: Category
    public let line: Int
    public let column: Int?
    public let message: String
    public let recommendation: String
    public let code: String?
    public let cwe: String?
    public var fullMessage: String
}
```

### `CodeMetrics`

```swift
public struct CodeMetrics: Codable, Sendable {
    public let linesOfCode: Int
    public let blankLines: Int
    public let commentLines: Int
    public let cyclomaticComplexity: Int
    public let maintainabilityIndex: Double
    public let duplicationPercentage: Double

    public var effectiveLinesOfCode: Int
    public var complexityRating: String
    public var maintainabilityRating: String
}
```

### `QualityScore`

```swift
public struct QualityScore: Codable, Sendable {
    public let overall: Double
    public let security: Double
    public let performance: Double
    public let maintainability: Double
    public let style: Double

    public var grade: String      // A-F
    public var rating: String     // Excellent-Very Poor

    public static func calculate(from issues: [Issue], metrics: CodeMetrics) -> QualityScore
}
```

### `AnalysisResult`

```swift
public struct AnalysisResult: Codable, Sendable {
    public let file: String
    public let language: ProgrammingLanguage
    public let issues: [Issue]
    public let metrics: CodeMetrics
    public let score: QualityScore
    public let analyzedAt: Date
    public let duration: TimeInterval

    public var issuesBySeverity: [Severity: [Issue]]
    public var issuesByCategory: [Category: [Issue]]
    public var errorCount: Int
    public var warningCount: Int
    public var infoCount: Int
    public var hasErrors: Bool
    public var summary: String
}
```

### `BatchAnalysisResult`

```swift
public struct BatchAnalysisResult: Codable, Sendable {
    public let results: [AnalysisResult]
    public let totalDuration: TimeInterval
    public let analyzedAt: Date

    public var totalIssues: Int
    public var totalErrors: Int
    public var totalWarnings: Int
    public var totalInfo: Int
    public var averageScore: Double
    public var summary: String
}
```

## Analyzers

### `SecurityAnalyzer`

```swift
public struct SecurityAnalyzer: CodeAnalyzer {
    public func analyze(_ file: SourceFile) async throws -> AnalysisResult
    public static func analyzeBatch(_ files: [SourceFile]) async throws -> BatchAnalysisResult
    public static func securitySummary(from result: AnalysisResult) -> SecuritySummary
}
```

### `PerformanceAnalyzer`

```swift
public struct PerformanceAnalyzer: CodeAnalyzer {
    public func analyze(_ file: SourceFile) async throws -> AnalysisResult
}
```

### `MetricsCalculator`

```swift
public struct MetricsCalculator: Sendable {
    public static func calculate(for file: SourceFile) -> CodeMetrics
    public static func summary(for metrics: CodeMetrics) -> MetricsSummary
}
```

## Rules

### `SecurityRules`

```swift
public struct SecurityRules: Sendable {
    public static let allRules: [SecurityRule]
    public static func rules(bySeverity: Severity) -> [SecurityRule]
    public static func rules(byCWE: String) -> [SecurityRule]
    public static func rule(byID: String) -> SecurityRule?
}
```

### `SecurityPatterns`

```swift
public struct SecurityPatterns: Sendable {
    public static func findMatches(for rule: SecurityRule, in file: SourceFile) -> [Issue]
    public static func findMatches(for rules: [SecurityRule], in file: SourceFile) -> [Issue]
    public static func findContextualVulnerabilities(in file: SourceFile) -> [Issue]
}
```

### `PerformancePatterns`

```swift
public struct PerformancePatterns: Sendable {
    public static let allPatterns: [PerformancePattern]
    public static func detectNestedLoops(in file: SourceFile) -> [Issue]
    public static func detectStringConcatInLoop(in file: SourceFile) -> [Issue]
    public static func detectArrayAppendWithoutCapacity(in file: SourceFile) -> [Issue]
    public static func detectSyncNetworkCalls(in file: SourceFile) -> [Issue]
    public static func detectArrayContainsInLoop(in file: SourceFile) -> [Issue]
    public static func detectFilterCount(in file: SourceFile) -> [Issue]
}
```

### `ComplexityAnalyzer`

```swift
public struct ComplexityAnalyzer: Sendable {
    public static func analyzeCyclomaticComplexity(_ file: SourceFile) -> [Issue]
    public static func calculateTotalComplexity(_ file: SourceFile) -> Int
    public static func analyzeNesting(_ file: SourceFile) -> [Issue]
}
```

### `CodeSmellDetector`

```swift
public struct CodeSmellDetector: Sendable {
    public static func detectLongMethods(_ file: SourceFile) -> [Issue]
    public static func detectLargeTypes(_ file: SourceFile) -> [Issue]
    public static func detectUnusedVariables(_ file: SourceFile) -> [Issue]
    public static func detectMagicNumbers(_ file: SourceFile) -> [Issue]
    public static func detectLongParameterLists(_ file: SourceFile) -> [Issue]
}
```

## Reports

### `ReportFormat`

```swift
public enum ReportFormat: String, CaseIterable, Sendable {
    case console, json, markdown
}
```

### `ReportGenerator`

```swift
public struct ReportGenerator: Sendable {
    public static func generate(_ result: AnalysisResult, format: ReportFormat) throws -> String
    public static func generate(_ batchResult: BatchAnalysisResult, format: ReportFormat) throws -> String
    public static func write(_ report: String, to path: String) throws
}
```

## Project Detection

### `ProjectType`

```swift
public enum ProjectType: String, Sendable, Codable, CaseIterable, Equatable {
    case swiftPackage, xcodeProject, nodeJS, react, nextJS,
         python, django, fastAPI, go, rust, java, springBoot,
         cpp, csharp, ruby, mixed, unknown

    public var displayName: String
}
```

### `ProjectTypeDetector`

```swift
public actor ProjectTypeDetector {
    public func detect(at directory: URL) async throws -> ProjectDetectionResult
}
```

## Panel

### `CodeAnalysisPanel`

```swift
public struct CodeAnalysisPanel: DevToolPanel {
    public let id = "devtools.analysis"
    public let title = "Code Analysis"
    public let icon = "magnifyingglass.circle"
    public let keyboardShortcut = DevToolsKeyboardShortcut(key: "a")

    public init(result: AnalysisResult? = nil)
}
```
