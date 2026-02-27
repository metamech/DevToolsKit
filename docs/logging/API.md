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
    public var filterLevel: DevToolsLogLevel     // default: .debug
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

```swift
public struct DevToolsLogEntry: Identifiable, Sendable {
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
    public init(label: String, store: DevToolsLogStore)
    public var logLevel: Logging.Logger.Level
    public var metadata: Logging.Logger.Metadata
}
```

Dispatches to `DevToolsLogStore` via `Task { @MainActor in store.append(entry) }`.

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
