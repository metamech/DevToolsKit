# Developer Guide: Diagnostic Export

Export a comprehensive JSON diagnostic report containing hardware info, developer settings, recent logs, and app-specific custom sections.

## Basic Export

The simplest path — use the Developer menu's "Export Diagnostics..." item, which calls the built-in exporter.

## Programmatic Export

```swift
let exporter = DiagnosticExporter(
    manager: devTools,
    logStore: logStore,
    appName: "MyApp"
)
await exporter.export()  // Presents NSSavePanel, writes JSON
```

## Custom Diagnostic Sections

Implement `DiagnosticProvider` to add app-specific data to the report:

```swift
struct NetworkDiagnostics: DiagnosticProvider {
    let sectionName = "network"

    func collect() async -> any Codable & Sendable {
        [
            "activeConnections": 3,
            "avgLatencyMs": 42,
            "endpoint": "api.example.com"
        ]
    }
}

devTools.registerDiagnosticProvider(NetworkDiagnostics())
```

The section name becomes a key in the exported JSON's `customSections` dictionary.

## Report Structure

The exported JSON includes:

```json
{
    "appName": "MyApp",
    "appVersion": "1.0.0",
    "macOSVersion": "15.2",
    "hardware": {
        "model": "arm64",
        "chipArchitecture": "arm64",
        "memoryGB": 32,
        "processorCount": 12
    },
    "developerSettings": {
        "isDeveloperMode": true,
        "logLevel": "debug"
    },
    "recentLogEntries": [...],
    "customSections": {
        "network": { ... }
    },
    "timestamp": "2026-01-15T10:30:00Z"
}
```

## Custom Export Handler

Override the default export behavior in `DevToolsCommands`:

```swift
DevToolsCommands(manager: devTools, onExportDiagnostics: {
    // Custom export logic
})
```

## Key Types

- `DiagnosticProvider` — Protocol: `sectionName` + `collect() async`
- `DiagnosticReport` — Codable report structure with nested types
- `DiagnosticExporter` — Orchestrates collection and NSSavePanel flow
- `AnyCodable` — Type-erased Codable wrapper for heterogeneous sections
