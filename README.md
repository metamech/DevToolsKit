# DevToolsKit

**In-app developer tools for macOS SwiftUI apps.**

[![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg)](https://swift.org)
[![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blue.svg)](https://developer.apple.com/macos/)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

DevToolsKit is a modular developer tools framework for macOS SwiftUI apps. Import only what you need — a core panel system with built-in panels, plus opt-in modules for logging, metrics, and feature flags.

## Modules

| Module | What it does | External Deps |
|--------|-------------|---------------|
| **DevToolsKit** | Core panel system, window management, diagnostic export, built-in panels | None |
| **DevToolsKitLogging** | swift-log integration with filterable log viewer panel | [swift-log](https://github.com/apple/swift-log) |
| **DevToolsKitMetrics** | swift-metrics integration with storage, query, and metrics inspector panel | [swift-metrics](https://github.com/apple/swift-metrics) |
| **DevToolsKitLicensing** | Feature flags, cohort experiments, percentage rollouts, license-tier gating | [swift-metrics](https://github.com/apple/swift-metrics) |
| **DevToolsKitProcess** | Process execution with timeout, stdout/stderr capture | None |

## Features

**Core**
- Panel system — standalone windows, shared tabbed window, or docked split view
- Environment panel — zero-config system info (macOS, hardware, memory, thermal)
- Performance dashboard — card-based metrics from your `MetricsProvider`
- Data inspector — collapsible JSON/dictionary tree view
- Diagnostic export — JSON reports with hardware, settings, logs, and custom sections
- Developer menu — auto-generated with keyboard shortcuts for every panel

**Logging** (opt-in)
- Filterable, searchable log viewer with FIFO capacity (⌘⌥L)
- swift-log `LogHandler` — all `Logger` output captured automatically

**Metrics** (opt-in)
- Metrics inspector with live view, query builder, and report tabs (⌘⌥I)
- swift-metrics `MetricsFactory` — all counters, timers, gauges captured automatically
- In-memory FIFO storage with query, aggregation, and percentile computation

**Feature Flags & Licensing** (opt-in)
- Feature flag definitions with categories, defaults, and license-tier gating (⌘⌥F)
- Percentage rollouts and multi-cohort A/B experiments
- Developer overrides with optional TTL expiry
- Pluggable license backends (LicenseSeat, StoreKit)

## Quick Start

```swift
.package(url: "https://github.com/metamech/DevToolsKit.git", from: "0.1.0")
```

```swift
import DevToolsKit
import DevToolsKitLogging   // opt-in
import DevToolsKitMetrics   // opt-in
import DevToolsKitLicensing // opt-in

@main struct MyApp: App {
    @State private var manager = DevToolsManager(keyPrefix: "myapp")
    @State private var logStore = DevToolsLogStore()
    @State private var metricsManager = MetricsManager()

    init() {
        // Core
        manager.register(EnvironmentPanel())

        // Logging
        LoggingSystem.bootstrap { DevToolsLogHandler(label: $0, store: logStore) }
        manager.register(LogPanel(logStore: logStore))

        // Metrics
        MetricsSystem.bootstrap(DevToolsMetricsFactory(storage: metricsManager.storage))
        manager.register(MetricsPanel(metricsManager: metricsManager))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .devToolsDock(manager)
                .environment(manager)
        }
        .commands { DevToolsCommands(manager: manager) }
    }
}
```

## Panels

| Panel | Module | ID | Shortcut |
|-------|--------|----|----------|
| EnvironmentPanel | Core | `devtools.environment` | ⌘⌥E |
| PerformancePanel | Core | `devtools.performance` | ⌘⌥M |
| DataInspectorPanel | Core | configurable | configurable |
| LogPanel | Logging | `devtools.log` | ⌘⌥L |
| MetricsPanel | Metrics | `devtools.metrics` | ⌘⌥I |
| FeatureFlagsPanel | Licensing | `devtools.feature-flags` | ⌘⌥F |

## Requirements

- macOS 15.0+
- Swift 6
- Xcode 16+

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/metamech/DevToolsKit.git", from: "0.1.0")
]
```

Then add only the products you need to your target:

```swift
.product(name: "DevToolsKit", package: "DevToolsKit"),           // Core (required)
.product(name: "DevToolsKitLogging", package: "DevToolsKit"),    // Optional
.product(name: "DevToolsKitMetrics", package: "DevToolsKit"),    // Optional
.product(name: "DevToolsKitLicensing", package: "DevToolsKit"),  // Optional
```

Or in Xcode: File > Add Package Dependencies, paste the repository URL.

## Documentation

- **[Documentation Index](docs/INDEX.md)** — All docs, organized by module
- [Quick Start](docs/core/QUICK_START.md) — Add DevToolsKit to your app in 4 steps
- [Core API](docs/core/API.md) | [Logging API](docs/logging/API.md) | [Metrics API](docs/metrics/API.md) | [Licensing API](docs/licensing/API.md) | [Process API](docs/process/API.md)
- [Feature Flags Guide](docs/licensing/FEATURE_FLAGS.md) — Define, gate, and override flags
- [Testing Patterns](docs/TESTING.md) — Unit testing with DevToolsKit
- [AI Coding Prompts](docs/AI_PROMPTS.md) — Template prompts for AI assistants
- [Contributing](docs/CONTRIBUTING.md) — Build, test, and submit changes

## License

[MIT](LICENSE) — Copyright (c) 2026 Metamech
