[< Guide](GUIDE.md) | [Index](../INDEX.md)

# DevToolsKitCodeAnalysisSwift API Reference

> Source: `Sources/DevToolsKitCodeAnalysisSwift/`
> Since: 0.4.0

## SwiftAnalyzer

```swift
public struct SwiftAnalyzer: CodeAnalyzer, Sendable {
    public init()
    public func analyze(_ file: SourceFile) async throws -> AnalysisResult
    public static func analyzeBatch(_ files: [SourceFile]) async throws -> BatchAnalysisResult
}
```

## SwiftSpecificRules

```swift
public struct SwiftSpecificRules: Sendable {
    public static func detectForceUnwraps(_ file: SourceFile) -> [Issue]
    public static func detectImplicitlyUnwrappedOptionals(_ file: SourceFile) -> [Issue]
    public static func detectPotentialRetainCycles(_ file: SourceFile) -> [Issue]
    public static func detectEmptyCatchBlocks(_ file: SourceFile) -> [Issue]
    public static func detectPrintStatements(_ file: SourceFile) -> [Issue]
    public static func detectTODOComments(_ file: SourceFile) -> [Issue]
    public static func detectForcedTypeCasting(_ file: SourceFile) -> [Issue]
}
```
