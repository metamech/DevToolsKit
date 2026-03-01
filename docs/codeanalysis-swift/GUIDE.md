[< Code Analysis](../codeanalysis/GUIDE.md) | [Index](../INDEX.md) | [API >](API.md)

# DevToolsKitCodeAnalysisSwift Guide

Swift-specific static analysis rules built on top of DevToolsKitCodeAnalysis.

## Setup

```swift
.product(name: "DevToolsKitCodeAnalysisSwift", package: "DevToolsKit")
```

```swift
import DevToolsKitCodeAnalysisSwift
```

## SwiftAnalyzer

`SwiftAnalyzer` implements `CodeAnalyzer` and runs both language-agnostic rules (complexity, code smells) and Swift-specific rules:

```swift
let analyzer = SwiftAnalyzer()
let result = try await analyzer.analyze(sourceFile)

for issue in result.issues {
    print("\(issue.line): [\(issue.code ?? "")] \(issue.message)")
}
```

## Batch Analysis

```swift
let batch = try await SwiftAnalyzer.analyzeBatch(files)
print("Total issues: \(batch.totalIssues)")
```

## Swift-Specific Rules

| Code | Rule | Severity |
|------|------|----------|
| SWIFT-001 | Force unwrap (`!`) | Warning |
| SWIFT-002 | Implicitly unwrapped optional | Info |
| SWIFT-003 | Potential retain cycle (missing `[weak self]`) | Warning |
| SWIFT-004 | Empty catch block | Warning |
| SWIFT-005 | Print statement (use proper logging) | Info |
| — | TODO comment | Info |
| — | FIXME comment | Warning |
| SWIFT-006 | Forced type cast (`as!`) | Warning |

## Using Individual Rules

You can also use `SwiftSpecificRules` methods directly:

```swift
let issues = SwiftSpecificRules.detectForceUnwraps(sourceFile)
let retainCycles = SwiftSpecificRules.detectPotentialRetainCycles(sourceFile)
```
