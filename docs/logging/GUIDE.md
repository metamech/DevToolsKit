# Logging Integration Guide

[Index](../INDEX.md) | [API Reference >](API.md)

> **Module:** `DevToolsKitLogging` — depends on DevToolsKit + [swift-log](https://github.com/apple/swift-log)
> **Since:** 0.1.0

## Installation

```swift
// Package.swift
.product(name: "DevToolsKitLogging", package: "DevToolsKit")
```

## Setup

```swift
import DevToolsKit
import DevToolsKitLogging
import Logging

let logStore = DevToolsLogStore(maxEntries: 5000)  // default: 10,000

// Bootstrap swift-log
LoggingSystem.bootstrap { label in
    DevToolsLogHandler(label: label, store: logStore)
}

// Register the log viewer panel
manager.register(LogPanel(logStore: logStore))

// Optional: include logs in diagnostic export
let exporter = DiagnosticExporter(manager: manager, logStore: logStore)
```

## Usage

Once bootstrapped, all standard swift-log calls route to the log store:

```swift
let logger = Logger(label: "myapp.network")
logger.info("Request completed", metadata: ["status": "200", "path": "/api/users"])
logger.error("Connection failed")
```

## Level Mapping

| swift-log Level | DevToolsLogLevel |
|----------------|------------------|
| trace | `.trace` |
| debug | `.debug` |
| info, notice | `.info` |
| warning | `.warning` |
| error, critical | `.error` |

## Direct Appending (without swift-log)

```swift
logStore.append(DevToolsLogEntry(
    timestamp: Date(),
    level: .info,
    source: "custom",
    message: "Direct entry",
    metadata: nil
))
```

## Log Panel Features (⌘⌥L)

- **Level filter** — Segmented picker: All, Debug, Info, Warning, Error
- **Source filter** — Dropdown of all known sources
- **Search** — Full-text search across messages
- **Copy All** — Copy all filtered entries to clipboard as text (⌘⇧C)
- **Export** — Export filtered entries as plain text or JSON via file save dialog
- **Auto-scroll** — Follows new entries in real time
- **Entry count** — Badge showing filtered count
- **Clear** — Remove all entries

## Copy & Export (since 0.6.0)

All copy and export operations respect active filters (level, source, search text). These features are available on macOS and iOS; they are hidden on tvOS and watchOS.

### Toolbar

The toolbar includes a **Copy All** button (`doc.on.clipboard` icon) that copies all filtered entries to the clipboard as formatted text. A bounce animation confirms the copy. Keyboard shortcut: **⌘⇧C**.

The **Export** menu (`square.and.arrow.up` icon) offers two options:
- **Export as Text...** — saves entries as a plain text file
- **Export as JSON...** — saves entries as a pretty-printed JSON array

Both use SwiftUI's `.fileExporter()` for a native save dialog.

### Context Menu

Right-click any log row for:
- **Copy Message** — copies just the message text
- **Copy Entry** — copies the full formatted line (timestamp, level, source, message, metadata)

## Filtering

`DevToolsLogStore` exposes bindable filter state:

```swift
logStore.filterLevel = .trace       // Show all entries (default)
logStore.filterLevel = .warning     // Show warning and above
logStore.filterSource = "network"   // Show only "network" source
logStore.searchText = "timeout"     // Full-text search
```

`filteredEntries` and `knownSources` are computed properties that update automatically.

## Log Panel Columns

The log panel displays four columns: **Time**, **Level**, **Source**, and **Message**.

### Resizable Columns

Drag the column dividers between headers to resize. Column widths persist to UserDefaults under keys:

- `{keyPrefix}.logColumn.timestamp` — default 85pt
- `{keyPrefix}.logColumn.level` — default 50pt
- `{keyPrefix}.logColumn.source` — default 160pt

The message column fills remaining space.

### Source Truncation

Reverse-DNS source labels (e.g., `com.metamech.maccad.canvas.view`) are automatically truncated to fit the source column width. Leading dot-separated components are stripped first, always preserving at least the last two components. Hover over a truncated source to see the full label in a tooltip.

## Dual Logging: os.Logger Forwarding (since 0.4.0)

By default, `DevToolsLogHandler` forwards all log messages to `os.Logger` in addition to the in-memory `DevToolsLogStore`. This means all swift-log output automatically appears in Console.app and `log stream`.

### How it works

- **Subsystem**: `Bundle.main.bundleIdentifier` (falls back to `"DevToolsKit"`)
- **Category**: The swift-log label (e.g., `"myapp.network"`)
- **Privacy**: `.public` — appropriate for developer-facing log messages
- **Level mapping**: trace/debug -> `.debug`, info/notice -> `.info`, warning -> `.default`, error/critical -> `.error`

### Disabling os.Logger forwarding

Pass `osLogForwarding: false` to keep logs only in `DevToolsLogStore`:

```swift
LoggingSystem.bootstrap { label in
    DevToolsLogHandler(label: label, store: logStore, osLogForwarding: false)
}
```

### Viewing in Console.app

1. Open Console.app
2. Filter by your app's bundle identifier (subsystem)
3. Enable "Include Info Messages" and "Include Debug Messages" as needed

Or from the terminal:

```bash
log stream --predicate 'subsystem == "com.yourapp.bundleid"' --level debug
```
