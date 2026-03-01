[< Diff](../diff/GUIDE.md) | [Index](../INDEX.md) | [API >](API.md)

# DevToolsKitCodeAnalysis Guide

Language-agnostic static code analysis for detecting security vulnerabilities, performance anti-patterns, code complexity, and code smells.

## Installation

Add to your target:

```swift
.product(name: "DevToolsKitCodeAnalysis", package: "DevToolsKit")
```

## Quick Start

```swift
import DevToolsKitCodeAnalysis

// Load a source file
let file = try SourceFile.load(from: fileURL)

// Run security analysis
let securityAnalyzer = SecurityAnalyzer()
let securityResult = try await securityAnalyzer.analyze(file)

// Run performance analysis
let perfAnalyzer = PerformanceAnalyzer()
let perfResult = try await perfAnalyzer.analyze(file)

// Generate a report
let report = try ReportGenerator.generate(securityResult, format: .markdown)
```

## Analyzers

### SecurityAnalyzer

Detects 25+ vulnerability patterns including:
- Hardcoded secrets (passwords, API keys, tokens) -- CWE-798
- SQL injection -- CWE-89
- Command injection -- CWE-78
- Path traversal -- CWE-22
- Insecure cryptography (MD5, SHA-1, DES) -- CWE-327
- Insecure data storage (UserDefaults for secrets) -- CWE-312
- Insecure HTTP connections -- CWE-319

```swift
let analyzer = SecurityAnalyzer()
let result = try await analyzer.analyze(file)
let summary = SecurityAnalyzer.securitySummary(from: result)
```

### PerformanceAnalyzer

Detects performance anti-patterns:
- Nested loops (O(n^2) complexity)
- String concatenation in loops
- Array append without capacity reservation
- Array.contains() in loops (use Set instead)
- filter().count patterns

### MetricsCalculator

Computes code quality metrics:
- Lines of code, blank lines, comment lines
- Cyclomatic complexity
- Maintainability index
- Code duplication percentage

```swift
let metrics = MetricsCalculator.calculate(for: file)
let summary = MetricsCalculator.summary(for: metrics)
```

## Rules

### ComplexityAnalyzer

Detects functions with high cyclomatic complexity (>10) and deeply nested code (>4 levels).

### CodeSmellDetector

Detects long methods (>50 lines), large types (>300 lines), unused variables, magic numbers, and long parameter lists (>5 params).

## Reports

Generate reports in three formats:

```swift
// Console output
let console = try ReportGenerator.generate(result, format: .console)

// JSON for machine consumption
let json = try ReportGenerator.generate(result, format: .json)

// Markdown for documentation/PRs
let md = try ReportGenerator.generate(result, format: .markdown)

// Write to file
try ReportGenerator.write(report, to: "/tmp/report.md")
```

## Project Type Detection

Detect project type from directory structure:

```swift
let detector = ProjectTypeDetector()
let result = try await detector.detect(at: projectURL)
print(result.primaryType.displayName) // "Swift Package"
print(result.frameworks) // ["React", "Express"]
```

Supports: Swift, Node.js, React, Next.js, Python, Django, FastAPI, Go, Rust, Java, Spring Boot, C++, C#/.NET, Ruby.

## Panel Integration

Register the code analysis panel with DevToolsKit:

```swift
import DevToolsKit
import DevToolsKitCodeAnalysis

let result = try await analyzer.analyze(file)
manager.register(CodeAnalysisPanel(result: result))
```

The panel shows quality scores, category breakdowns, and a filterable issue list. Shortcut: Command+Option+A.

## Custom Analyzers

Implement the `CodeAnalyzer` protocol:

```swift
struct MyAnalyzer: CodeAnalyzer {
    func analyze(_ file: SourceFile) async throws -> AnalysisResult {
        var issues: [Issue] = []
        // Your analysis logic...
        return AnalysisResult(
            file: file.path,
            language: file.language,
            issues: issues
        )
    }
}
```
