# Logging API Reference

[< Guide](GUIDE.md) | [Index](../INDEX.md)

> **Source:** `Sources/DevToolsKitLogging/`
> **Since:** 0.1.0

## DevToolsLogStore

```swift
@MainActor @Observable
public final class DevToolsLogStore: Sendable {
    public init(maxEntries: Int = 10_000)

    // Entries
    public private(set) var entries: [DevToolsLogEntry]
    public var filteredEntries: [DevToolsLogEntry]  // computed

    // Filters (bindable)
    public var filterLevel: DevToolsLogLevel     // default: .trace
    public var filterSource: String?             // default: nil (all)
    public var searchText: String                // default: ""

    // Computed
    public var knownSources: [String]

    // Actions
    public func append(_ entry: DevToolsLogEntry)
    public func clear()
    public func recentEntries(_ count: Int) -> [DevToolsLogEntry]
}
```

## DevToolsLogEntry

> Since: 0.1.0 (Codable since 0.6.0)

```swift
public struct DevToolsLogEntry: Identifiable, Sendable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let level: DevToolsLogLevel
    public let source: String
    public let message: String
    public let metadata: String?  // Pre-serialized key=value pairs
}
```

## DevToolsLogHandler

```swift
public struct DevToolsLogHandler: LogHandler, @unchecked Sendable {
    public init(label: String, store: DevToolsLogStore, osLogForwarding: Bool = true)  // since 0.4.0
    public var logLevel: Logging.Logger.Level
    public var metadata: Logging.Logger.Metadata
}
```

Dispatches to `DevToolsLogStore` via `Task { @MainActor in store.append(entry) }`.

### os.Logger Forwarding (since 0.4.0)

When `osLogForwarding` is `true` (the default), all log messages are also forwarded to `os.Logger` so they appear in Console.app. The subsystem is `Bundle.main.bundleIdentifier` and the category is the swift-log label. Messages use `.public` privacy.

## LogPanel

```swift
public struct LogPanel: DevToolPanel {
    public let id = "devtools.log"          // ⌘⌥L
    public init(logStore: DevToolsLogStore)
}
```

## DiagnosticLogProvider Conformance

`DevToolsLogStore` conforms to `DiagnosticLogProvider`, enabling log entries to appear in the `recentLogEntries` section of diagnostic exports:

```swift
let exporter = DiagnosticExporter(manager: manager, logStore: logStore)
```

## LogEntryFormatter

> Since: 0.6.0

```swift
public enum LogEntryFormatter: Sendable {
    public static func formatLine(_ entry: DevToolsLogEntry) -> String
    public static func formatText(_ entries: [DevToolsLogEntry]) -> String
    public static func formatJSON(_ entries: [DevToolsLogEntry]) throws -> String
    @MainActor public static func copyToClipboard(_ text: String)  // macOS/iOS only
}
```

Formats log entries as human-readable text (ISO 8601 timestamp, 3-letter level code, source, message) or pretty-printed JSON. `copyToClipboard(_:)` is unavailable on tvOS and watchOS.

## LogExportDocument

> Since: 0.6.0

```swift
public struct LogExportDocument: FileDocument {
    public init(entries: [DevToolsLogEntry], format: LogExportFormat)
}

public enum LogExportFormat: Sendable {
    case plainText
    case json
}
```

A `FileDocument` for use with SwiftUI's `.fileExporter()`. Wraps formatted log entries in either plain text or JSON format.
