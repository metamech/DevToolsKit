# Developer Guide: Overview

DevToolsKit is a Swift package that adds in-app developer tools to macOS SwiftUI applications. It provides a panel system with built-in panels for logging, performance monitoring, environment inspection, and data inspection, plus a protocol for creating custom panels.

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  Your macOS App                  │
├─────────────────────────────────────────────────┤
│  DevToolsCommands         (Developer menu)       │
│  .devToolsDock(_:)         (Dock modifier)        │
├─────────────────────────────────────────────────┤
│               DevToolsManager                    │
│  ┌─────────┐ ┌──────────┐ ┌──────────────────┐  │
│  │ Panels  │ │ Display  │ │ Diagnostic       │  │
│  │ Registry│ │ Modes    │ │ Providers        │  │
│  └─────────┘ └──────────┘ └──────────────────┘  │
├─────────────────────────────────────────────────┤
│  Window Layer                                    │
│  ┌────────────┐ ┌─────────────┐ ┌────────────┐  │
│  │ Standalone │ │ Tabbed      │ │ Dock       │  │
│  │ NSWindow   │ │ NSWindow    │ │ SplitView  │  │
│  └────────────┘ └─────────────┘ └────────────┘  │
├─────────────────────────────────────────────────┤
│  Built-in Panels                                 │
│  ┌─────┐ ┌───────────┐ ┌───────────┐ ┌───────┐  │
│  │ Log │ │Performance│ │Environment│ │ Data  │  │
│  └─────┘ └───────────┘ └───────────┘ └───────┘  │
└─────────────────────────────────────────────────┘
```

## Key Concepts

- **DevToolsManager** — Central `@Observable` registry that owns all state: registered panels, display modes, dock visibility, and diagnostic providers. Persists preferences to `UserDefaults` under a configurable key prefix.
- **DevToolPanel** — Protocol that every panel (built-in or custom) conforms to. Panels are value types that describe themselves and produce a view on demand.
- **Display Modes** — Each panel can be shown in one of three modes: standalone window, tabbed window, or docked to app content.
- **DiagnosticProvider** — Protocol for contributing app-specific sections to the JSON diagnostic export.

## Directory Layout

```
Sources/DevToolsKit/
├── Core/               # DevToolPanel, DevToolsManager, configuration enums
├── Menu/               # DevToolsCommands (Developer menu)
├── Modifiers/          # .devToolsDock() ViewModifier
├── Window/             # Standalone + tabbed window managers, dock view
├── Panels/
│   ├── LogPanel/       # Log viewer + DevToolsLogStore + swift-log handler
│   ├── PerformancePanel/  # Metrics dashboard + MetricsProvider protocol
│   ├── EnvironmentPanel/  # System info panel (zero config)
│   └── DataInspectorPanel/  # JSON/dict tree inspector
└── Export/             # DiagnosticProvider, DiagnosticReport, exporter
```

## Next Steps

- [Quick Start](DEVELOPER_GUIDE_01_QUICK_START.md) — Add DevToolsKit to your app in 4 steps
- [Panel System](DEVELOPER_GUIDE_02_PANEL_SYSTEM.md) — Create custom panels
- [API Reference](API_01_CORE.md) — Full type signatures
