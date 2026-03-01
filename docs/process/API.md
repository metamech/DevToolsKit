[< Guide](GUIDE.md) | [Index](../INDEX.md)

# DevToolsKitProcess API Reference

> Source: `Sources/DevToolsKitProcess/`
> Since: 0.4.0

## ProcessResult

```swift
public struct ProcessResult: Sendable, Identifiable {
    public let id: UUID
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
    public let duration: TimeInterval
    public let startedAt: Date
    public var succeeded: Bool { get }

    public init(
        id: UUID = UUID(),
        exitCode: Int32,
        stdout: String,
        stderr: String,
        duration: TimeInterval,
        startedAt: Date = Date()
    )
}
```

## ProcessExecutionError

```swift
public enum ProcessExecutionError: Error, LocalizedError, Sendable {
    case timeout(TimeInterval)
    case executionFailed(String)
}
```

## ProcessExecutor

```swift
public struct ProcessExecutor: Sendable {
    /// Executes a command synchronously.
    public static func execute(
        _ executable: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        environment: [String: String]? = nil
    ) throws -> ProcessResult

    /// Executes a command asynchronously with optional timeout.
    public static func executeAsync(
        _ executable: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        environment: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> ProcessResult

    /// Executes a shell command via /bin/bash.
    public static func executeShell(
        _ command: String,
        workingDirectory: URL? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> ProcessResult

    /// Formats process output for display.
    public static func formatOutput(
        _ result: ProcessResult,
        includeStderr: Bool = true
    ) -> String
}
```
