[< Guide](GUIDE.md) | [Index](../INDEX.md)

# DevToolsKitDiff API Reference

> Source: `Sources/DevToolsKitDiff/`
> Since: 0.4.0

## Types

### Diff
```swift
public struct Diff: Sendable, Equatable {
    public let originalFile: String
    public let modifiedFile: String
    public let hunks: [Hunk]
}
```

### Hunk
```swift
public struct Hunk: Sendable, Equatable {
    public let originalStart: Int
    public let originalCount: Int
    public let modifiedStart: Int
    public let modifiedCount: Int
    public let lines: [DiffLine]
}
```

### DiffLine
```swift
public enum DiffLine: Sendable, Equatable {
    case context(String)
    case addition(String)
    case deletion(String)

    public var content: String
}
```

### DiffError
```swift
public enum DiffError: Error, LocalizedError, Sendable, Equatable {
    case invalidDiff(String)
    case applicationFailed(String)
    case fileReadFailed(String)
    case fileWriteFailed(String)
}
```

## Engine

### DiffEngine
```swift
public struct DiffEngine: Sendable {
    public init()
    public func parse(_ diffText: String) throws -> Diff
    public func apply(_ diff: Diff, to fileURL: URL, dryRun: Bool) throws
    public func apply(_ diff: Diff, to content: String) throws -> String
    public func validate(_ diff: Diff) -> [String]
}
```
