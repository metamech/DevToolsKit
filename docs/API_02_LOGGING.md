# API Reference: Logging

> Source: `Sources/DevToolsKit/Panels/LogPanel/`

## DevToolsLogStore

```swift
@MainActor @Observable
public final class DevToolsLogStore: Sendable {
    public init(maxEntries: Int = 5000)

    public private(set) var entries: [DevToolsLogEntry]
    public var filterLevel: DevToolsLogLevel        // default: .debug
    public var filterSource: String?                // default: nil (all)
    public var searchText: String                   // default: ""
    public var knownSources: [String]               // computed, sorted
    public var filteredEntries: [DevToolsLogEntry]  // computed
    public let maxEntries: Int

    public func append(_ entry: DevToolsLogEntry)
    public func clear()
    public func recentEntries(_ count: Int = 100) -> [DevToolsLogEntry]
}
```

FIFO-capped log entry store with filter state. Entries beyond `maxEntries` are trimmed from the front.

## DevToolsLogEntry

```swift
public struct DevToolsLogEntry: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let level: DevToolsLogLevel
    public let source: String
    public let message: String
    public let metadata: String?

    public init(
        level: DevToolsLogLevel,
        source: String,
        message: String,
        metadata: String? = nil,
        timestamp: Date = Date()
    )
}
```

A single log entry with level, source label, message, and optional metadata.

## DevToolsLogHandler

```swift
public struct DevToolsLogHandler: LogHandler, @unchecked Sendable {
    public var logLevel: Logging.Logger.Level
    public var metadata: Logging.Logger.Metadata

    public init(label: String, store: DevToolsLogStore)
    public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value?
    public func log(level:message:metadata:source:file:function:line:)
}
```

[swift-log](https://github.com/apple/swift-log) `LogHandler` that forwards entries to a `DevToolsLogStore` via `Task { @MainActor in }`.

## LogPanel

```swift
public struct LogPanel: DevToolPanel {
    public let id = "devtools.log"
    public let title = "Log Viewer"
    public let icon = "doc.text.magnifyingglass"
    public let keyboardShortcut = DevToolsKeyboardShortcut(key: "l")  // ⌘⌥L

    public init(logStore: DevToolsLogStore)
    public func makeBody() -> AnyView
}
```

## LogPanelView

```swift
public struct LogPanelView: View {
    public init(logStore: DevToolsLogStore)
    public var body: some View
}
```

Filterable log viewer UI with toolbar, level filter, source picker, search, auto-scroll, and clear.
