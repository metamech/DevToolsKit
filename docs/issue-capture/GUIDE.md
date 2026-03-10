[Index](../INDEX.md) | [API Reference >](API.md)

# DevToolsKitIssueCapture Guide

> Since 0.5.0

Quick recurring-issue capture for debugging discrepancies between actual and expected app state.

## Motivation

When your app displays state that doesn't match reality (e.g., shows "working" when it should show "needs input"), you need a fast way to capture:
1. What the app is currently showing (auto-captured)
2. What you expected it to show (you select/type)
3. Optional notes and a screenshot

Over time, these captures reveal patterns that help identify root causes.

## Installation

```swift
.product(name: "DevToolsKitIssueCapture", package: "DevToolsKit")
```

## Quick Start

### 1. Create a Provider

```swift
import DevToolsKitIssueCapture

struct SessionStateProvider: IssueCaptureProvider {
    let id = "session.state"
    let displayName = "Session State"

    let session: SessionManager

    func captureCurrentState() async -> [String: String] {
        [
            "status": session.status.rawValue,
            "lastUpdate": session.lastUpdate.formatted(),
        ]
    }

    var expectedStateFields: [IssueCaptureField] {
        [
            .quickSelect(id: "status", label: "Expected Status",
                         options: ["working", "idle", "needsInput", "error"]),
            .text(id: "reason", label: "Why?", placeholder: "Describe the discrepancy"),
        ]
    }
}
```

### 2. Set Up the Store and Panel

```swift
let capturesDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("IssueCaptures")
let store = IssueCaptureStore(storageDirectory: capturesDir)
let providers: [any IssueCaptureProvider] = [SessionStateProvider(session: session)]

manager.register(IssueCapturePanel(store: store, providers: providers))
```

### 3. Add Quick Capture (optional)

```swift
ContentView()
    .quickCaptureSheet(isPresented: $showCapture, store: store, providers: providers)
```

## Field Types

| Type | Usage |
|------|-------|
| `.text` | Free-form text input |
| `.quickSelect` | Single selection from a list |
| `.multiSelect` | Multiple selections from a list |

## Store Features

### Filtering

```swift
store.filterProviderID = "session.state"
store.filterTag = "ui"
store.searchText = "timeout"
store.filterDateRange = lastWeek...Date()
let matches = store.filteredCaptures
```

### Analysis

```swift
// Most common expected values for a field
let common = store.commonExpectedValues(fieldID: "status")
// → [("needsInput", 12), ("error", 3)]

// Capture frequency over time
let frequency = store.captureFrequency
// → [(2026-03-01, 5), (2026-03-02, 3), ...]
```

### Export

```swift
let jsonData = try store.exportFiltered()
// Screenshots are stripped for compact export
```

## Persistence

Captures are stored as individual JSON files named `{UUID}.json` in the configured storage directory. Screenshots are base64-encoded within the JSON. The store auto-creates the directory on first save.

## Diagnostic Integration

`IssueCaptureStore` conforms to `DiagnosticProvider`, reporting a summary of captures (without screenshots) under the `"issueCaptures"` section in diagnostic exports.

```swift
manager.registerDiagnosticProvider(store)
```
