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
- **Auto-scroll** — Follows new entries in real time
- **Entry count** — Badge showing filtered count
- **Clear** — Remove all entries

## Filtering

`DevToolsLogStore` exposes bindable filter state:

```swift
logStore.filterLevel = .trace       // Show all entries (default)
logStore.filterLevel = .warning     // Show warning and above
logStore.filterSource = "network"   // Show only "network" source
logStore.searchText = "timeout"     // Full-text search
```

`filteredEntries` and `knownSources` are computed properties that update automatically.
