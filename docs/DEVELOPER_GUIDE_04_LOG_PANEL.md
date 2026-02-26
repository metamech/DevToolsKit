[< Window Modes](DEVELOPER_GUIDE_03_WINDOW_MODES.md) | [Index](DEVELOPER_GUIDE_00_OVERVIEW.md) | [Performance Panel >](DEVELOPER_GUIDE_05_PERFORMANCE_PANEL.md)

# Developer Guide: Log Panel

The Log Viewer panel displays a filterable, searchable stream of log entries.

## Setup

```swift
let logStore = DevToolsLogStore()
devTools.register(LogPanel(logStore: logStore))
```

## DevToolsLogStore

`DevToolsLogStore` is an `@Observable` FIFO buffer:

- **Capacity** — Configurable via `init(maxEntries:)`, default 5000. Oldest entries are trimmed when exceeded.
- **Filters** — `filterLevel` (minimum severity), `filterSource` (exact match or nil for all), `searchText` (case-insensitive substring match on message).
- **Computed** — `filteredEntries` applies all active filters. `knownSources` returns sorted unique source labels.

## Adding Entries Directly

```swift
logStore.append(DevToolsLogEntry(
    level: .info,
    source: "MySubsystem",
    message: "Operation completed",
    metadata: "duration=42ms"
))
```

## swift-log Integration

`DevToolsLogHandler` is a `LogHandler` that forwards entries to `DevToolsLogStore`:

```swift
import Logging

LoggingSystem.bootstrap { label in
    DevToolsLogHandler(label: label, store: logStore)
}

// Now standard Logger calls appear in the panel
let logger = Logger(label: "Network")
logger.info("Request sent", metadata: ["url": "\(url)"])
```

Level mapping:
| swift-log | DevToolsLogLevel |
|-----------|-----------------|
| `.trace`, `.debug` | `.debug` |
| `.info`, `.notice` | `.info` |
| `.warning` | `.warning` |
| `.error`, `.critical` | `.error` |

## Log Panel UI

The panel provides:
- Level filter (segmented control: Debug / Info / Warning / Error)
- Source picker (dropdown of known sources)
- Search field (substring match on message)
- Entry count display
- Auto-scroll toggle
- Clear button
- Monospaced font with color-coded level badges

---

[< Window Modes](DEVELOPER_GUIDE_03_WINDOW_MODES.md) | [Index](DEVELOPER_GUIDE_00_OVERVIEW.md) | [Performance Panel >](DEVELOPER_GUIDE_05_PERFORMANCE_PANEL.md)
