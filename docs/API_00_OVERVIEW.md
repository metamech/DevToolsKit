# API Reference: Overview

DevToolsKit's public API is organized around a central manager, a panel protocol, and supporting types for logging, metrics, inspection, export, and window management.

## Concepts

### The Manager Pattern

`DevToolsManager` is the single source of truth. It owns the panel registry, display mode preferences, dock state, and diagnostic provider list. All state mutations flow through it; SwiftUI views observe it reactively via `@Observable`.

```swift
@State private var devTools = DevToolsManager(keyPrefix: "myapp")
```

### Panels as Value Types

Panels conform to the `DevToolPanel` protocol — they're lightweight structs that describe themselves (id, title, icon, shortcut, sizes) and produce a view on demand via `makeBody() -> AnyView`. The manager stores them; the window layer renders them.

### Three Display Modes

Every panel can be shown as a standalone `NSWindow`, as a tab in the shared tabbed window, or docked to the app content in a split view. The mode is persisted per-panel to `UserDefaults`.

### Provider Protocols

Two provider protocols extend the system:
- **`MetricsProvider`** — Supply numeric metrics to the performance dashboard
- **`DiagnosticProvider`** — Contribute custom sections to the JSON diagnostic export

Both are `@MainActor` and `Sendable`, and use `async` collection methods.

### swift-log Bridge

`DevToolsLogHandler` implements the `LogHandler` protocol from [swift-log](https://github.com/apple/swift-log), forwarding entries into a `DevToolsLogStore` for display in the Log Viewer panel.

## Table of Contents

| # | Document | Coverage |
|---|----------|----------|
| 1 | [Core](API_01_CORE.md) | `DevToolPanel`, `DevToolsManager`, `DevToolsKeyboardShortcut`, `PanelDisplayMode`, `DockPosition`, `DevToolsLogLevel` |
| 2 | [Logging](API_02_LOGGING.md) | `DevToolsLogStore`, `DevToolsLogEntry`, `DevToolsLogHandler`, `LogPanel`, `LogPanelView` |
| 3 | [Metrics](API_03_METRICS.md) | `MetricsProvider`, `MetricGroup`, `Metric`, `MetricColor`, `PerformancePanel`, `PerformancePanelView` |
| 4 | [Inspector & Environment](API_04_INSPECTOR_ENVIRONMENT.md) | `DataInspectorPanel`, `DataInspectorView`, `EnvironmentPanel`, `EnvironmentPanelView` |
| 5 | [Export](API_05_EXPORT.md) | `DiagnosticProvider`, `DiagnosticReport`, `DiagnosticExporter`, `AnyCodable` |
| 6 | [Window, Menu & Modifiers](API_06_WINDOW_MENU_MODIFIERS.md) | `DevToolsWindowManager`, `DevToolsTabbedWindow`, `DevToolsCommands`, `.devToolsDock(_:)` |

## Related

- [Developer Guide](DEVELOPER_GUIDE_00_OVERVIEW.md) — Tutorials and usage patterns
- [README](../README.md) — Quick start and feature overview

---

Next: [Core](API_01_CORE.md)
