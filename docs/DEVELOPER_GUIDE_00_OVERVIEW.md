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

## Table of Contents

| # | Chapter | Description |
|---|---------|-------------|
| 0 | **Overview** (this document) | Architecture, key concepts, directory layout |
| 1 | [Quick Start](DEVELOPER_GUIDE_01_QUICK_START.md) | Add DevToolsKit to your app in 4 steps |
| 2 | [Panel System](DEVELOPER_GUIDE_02_PANEL_SYSTEM.md) | `DevToolPanel` protocol, custom panels, shortcuts |
| 3 | [Window Modes](DEVELOPER_GUIDE_03_WINDOW_MODES.md) | Standalone, tabbed, docked — behavior and transitions |
| 4 | [Log Panel](DEVELOPER_GUIDE_04_LOG_PANEL.md) | Log Viewer, `DevToolsLogStore`, swift-log integration |
| 5 | [Performance Panel](DEVELOPER_GUIDE_05_PERFORMANCE_PANEL.md) | `MetricsProvider`, metric groups, dashboard UI |
| 6 | [Data & Environment](DEVELOPER_GUIDE_06_DATA_ENVIRONMENT.md) | Data Inspector, Environment panel |
| 7 | [Diagnostic Export](DEVELOPER_GUIDE_07_DIAGNOSTIC_EXPORT.md) | `DiagnosticProvider`, report structure, export flow |
| 8 | [Menu Integration](DEVELOPER_GUIDE_08_MENU_INTEGRATION.md) | `DevToolsCommands`, Developer menu |
| 9 | [Testing](DEVELOPER_GUIDE_09_TESTING.md) | Testing with DevToolsKit, mock panels, key prefix isolation |
| 10 | [AI Prompts](DEVELOPER_GUIDE_10_AI_PROMPTS.md) | Recommended prompts for AI coding assistants |

## Related

- [API Reference](API_00_OVERVIEW.md) — Full type signatures and declarations
- [README](../README.md) — Quick start and feature overview

---

Next: [Quick Start](DEVELOPER_GUIDE_01_QUICK_START.md)
