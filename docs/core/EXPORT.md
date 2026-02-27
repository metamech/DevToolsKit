# Diagnostic Export

[< Window Modes](WINDOW_MODES.md) | [Index](../INDEX.md) | [Menu >](MENU.md)

> **Module:** `DevToolsKit`

Export a JSON diagnostic report containing hardware info, app settings, logs, and custom sections.

## Basic Export (via Menu)

The Developer menu includes **"Export Diagnostics..."** which presents an `NSSavePanel` and writes a pretty-printed JSON file.

## Programmatic Export

```swift
let exporter = DiagnosticExporter(
    manager: manager,
    logStore: logStore,    // optional, from DevToolsKitLogging
    appName: "MyApp"       // optional, auto-detected from bundle
)
await exporter.export()
```

## Custom Diagnostic Providers

Add your own sections to the report by conforming to `DiagnosticProvider`:

```swift
struct NetworkDiagnostics: DiagnosticProvider {
    let sectionName = "network"

    func collect() async -> any Codable & Sendable {
        ["latency_ms": 42, "connected": true, "endpoint": "api.example.com"]
    }
}

manager.registerDiagnosticProvider(NetworkDiagnostics())
```

Modules that conform: `DevToolsLogStore` (via `DiagnosticLogProvider`), `MetricsManager`, `LicensingManager`.

## Report Structure

```json
{
  "appName": "MyApp",
  "appVersion": "1.0.0",
  "macOSVersion": "15.2",
  "hardware": { "model": "Mac16,1", "chip": "Apple M4 Pro", ... },
  "developerSettings": { "isDeveloperMode": true, "logLevel": "debug", ... },
  "recentLogEntries": [ ... ],
  "customSections": {
    "network": { "latency_ms": 42, ... },
    "metrics": [ ... ],
    "licensing": { ... }
  },
  "timestamp": "2026-02-27T..."
}
```

## Custom Export Handler

Override the default save panel behavior:

```swift
DevToolsCommands(manager: manager, onExportDiagnostics: {
    // Custom export logic
})
```
