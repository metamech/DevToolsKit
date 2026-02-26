# DevToolsKit

**In-app developer tools for macOS SwiftUI apps.**

[![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg)](https://swift.org)
[![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blue.svg)](https://developer.apple.com/macos/)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

DevToolsKit adds a full-featured developer tools overlay to any macOS SwiftUI app — log viewer, performance dashboard, environment inspector, data inspector, and diagnostic export — with zero configuration for built-in panels and a simple protocol for custom ones.

## Features

- **Panel system** — Register built-in or custom panels; open them as standalone windows, in a shared tabbed window, or docked to your app content
- **Log Viewer** — Filterable, searchable log stream with FIFO capacity; integrates with [swift-log](https://github.com/apple/swift-log) via `DevToolsLogHandler`
- **Performance Dashboard** — Card-based metric display fed by your own `MetricsProvider`
- **Environment Panel** — Zero-config system info: macOS version, hardware, memory, thermal state, app metadata
- **Data Inspector** — Collapsible tree view for JSON or key-value data
- **Diagnostic Export** — Collect hardware info, settings, logs, and custom sections into a single JSON file via `NSSavePanel`
- **Developer Menu** — Auto-generated "Developer" menu with keyboard shortcuts for every panel
- **Persistence** — Panel display modes, dock position, and developer settings survive app restarts via `UserDefaults`

## Quick Start

```swift
// 1. Add the dependency to Package.swift
.package(url: "https://github.com/metamech/DevToolsKit.git", from: "1.0.0")

// 2. Set up in your App
import DevToolsKit

@main struct MyApp: App {
    @State private var devTools = DevToolsManager(keyPrefix: "myapp")
    @State private var logStore = DevToolsLogStore()

    init() {
        devTools.register(LogPanel(logStore: logStore))
        devTools.register(PerformancePanel(provider: MyMetricsProvider()))
        devTools.register(EnvironmentPanel())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .devToolsDock(devTools)
                .environment(devTools)
        }
        .commands {
            DevToolsCommands(manager: devTools)
        }
    }
}
```

## Built-in Panels

| Panel | ID | Shortcut | Description |
|-------|-----|----------|-------------|
| `LogPanel` | `devtools.log` | ⌘⌥L | Filterable log viewer with swift-log integration |
| `PerformancePanel` | `devtools.performance` | ⌘⌥M | Metric card dashboard from your `MetricsProvider` |
| `EnvironmentPanel` | `devtools.environment` | ⌘⌥E | System and app info (zero config) |
| `DataInspectorPanel` | configurable | configurable | Collapsible JSON/dict tree view |

## Custom Panels

```swift
struct AgentConfigPanel: DevToolPanel {
    let id = "myapp.agent-config"
    let title = "Agent Config"
    let icon = "gearshape"
    let keyboardShortcut = DevToolsKeyboardShortcut(key: "a")

    func makeBody() -> AnyView {
        AnyView(AgentConfigView())
    }
}

// Register it
devTools.register(AgentConfigPanel())
```

## Logging Integration

DevToolsKit bridges [swift-log](https://github.com/apple/swift-log) into the log viewer panel:

```swift
import Logging

let logStore = DevToolsLogStore()
LoggingSystem.bootstrap { label in
    DevToolsLogHandler(label: label, store: logStore)
}

// Now any Logger output appears in the Log Viewer panel
let logger = Logger(label: "MyApp")
logger.info("App started")
```

## Diagnostic Export

Export a JSON report with hardware info, settings, recent logs, and custom sections:

```swift
struct NetworkDiagnostics: DiagnosticProvider {
    let sectionName = "network"
    func collect() async -> any Codable & Sendable {
        ["activeConnections": 3, "avgLatencyMs": 42]
    }
}

devTools.registerDiagnosticProvider(NetworkDiagnostics())

// Export via menu or programmatically:
let exporter = DiagnosticExporter(manager: devTools, logStore: logStore)
await exporter.export()  // Opens NSSavePanel
```

## Requirements

- macOS 15.0+
- Swift 6
- Xcode 16+

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/metamech/DevToolsKit.git", from: "1.0.0")
]
```

Or in Xcode: File > Add Package Dependencies, paste the URL.

## Documentation

- [Developer Guide](docs/DEVELOPER_GUIDE_00_OVERVIEW.md) — Architecture, quick start, and deep dives
- [API Reference](docs/API_01_CORE.md) — Full type signatures and descriptions
- [Contributing](docs/CONTRIBUTING.md) — How to build, test, and submit changes
- [AI Instructions](docs/CLAUDE.md) — Claude Code / Copilot integration guide

## Contributing

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for build instructions, code style, and PR process.

## License

[MIT](LICENSE) — Copyright (c) 2026 Metamech
