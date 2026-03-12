# Contributing to DevToolsKit

[Index](INDEX.md)

## Prerequisites

- macOS 26+
- Xcode 26+
- Swift 6

## Clone, Build & Test

```bash
git clone https://github.com/metamech/DevToolsKit.git
cd DevToolsKit
swift build
swift test
```

## Project Structure

```
Sources/
├── DevToolsKit/              # Core (no external deps)
│   ├── Core/                 # DevToolPanel, DevToolsManager, config
│   ├── Menu/                 # DevToolsCommands
│   ├── Modifiers/            # .devToolsDock() modifier
│   ├── Window/               # Standalone + tabbed windows, dock view
│   ├── Panels/               # Built-in: Environment, Performance, DataInspector
│   └── Export/               # DiagnosticProvider, DiagnosticReport, exporter
├── DevToolsKitLogging/       # swift-log integration
├── DevToolsKitMetrics/       # swift-metrics integration
├── DevToolsKitLicensing/     # Feature flags, experimentation, licensing
├── DevToolsKitLicensingSeat/ # LicenseSeat backend
├── DevToolsKitLicensingStoreKit/ # StoreKit backend
├── DevToolsKitProcess/      # Process execution (macOS only)
├── DevToolsKitSecurity/     # Permissions, sandbox, bookmarks
├── DevToolsKitGitHub/       # GitHub REST API client
├── DevToolsKitDiff/         # Unified diff parsing
├── DevToolsKitCodeAnalysis/ # Code analysis engine
├── DevToolsKitCodeAnalysisSwift/ # Swift-specific rules
├── DevToolsKitMetricsStore/ # Persistent SwiftData metrics
├── DevToolsKitScreenCapture/ # Screen capture + history panel
└── DevToolsKitIssueCapture/ # Issue capture + panel
Tests/
├── DevToolsKit{Module}Tests/         # Unit tests per module
└── DevToolsKit{Module}FlowTests/     # UI flow tests (SwiftUIFlowTesting)
Examples/
└── DevToolsKitDemo/         # Interactive demo app (macOS, all panels)
```

## Adding a New Panel

1. Create a directory under the appropriate module's `Panels/`
2. Add a struct conforming to `DevToolPanel` (e.g., `YourPanel.swift`)
3. Add the panel view (e.g., `YourPanelView.swift`)
4. Add `///` doc comments on all public items
5. Add unit tests in `Tests/DevToolsKit{Module}Tests/`
6. Add UI flow tests in `Tests/DevToolsKit{Module}FlowTests/` using [SwiftUIFlowTesting](https://github.com/metamech/SwiftUIFlowTesting)
7. Register the panel in the demo app (`Examples/DevToolsKitDemo/`)
8. Update docs under `docs/` for the relevant module
9. Run `swift build && swift test`

## Demo App

The demo app in `Examples/DevToolsKitDemo/` registers all panels with mock data for interactive testing:

```bash
cd Examples/DevToolsKitDemo && swift run
```

When adding a new panel, add it to the demo app so it can be tested interactively. Add any required mock types to `MockData.swift` and register the panel in `DevToolsKitDemoApp.swift`.

## Code Style

- **Swift 6** with strict concurrency
- **`@MainActor`** on all view-related types and protocols
- **`Sendable`** conformance on all public types
- **`///` doc comments** on all public items
- Follow naming conventions: `*Panel`, `*PanelView`, `*Provider`, `*Handler`

## Documentation

When adding or modifying features, update the corresponding docs:
- Module guide in `docs/{module}/GUIDE.md`
- API reference in `docs/{module}/API.md`
- Add version annotation (e.g., "Since 0.x.0") for new types/features

## GitHub Flow

1. Create an issue describing the change
2. Branch from `main`: `<type>/<issue>-<slug>` (e.g., `feat/42-add-network-panel`)
3. Commit in logical phases
4. Open a PR against `main`
5. Ensure `swift build` and `swift test` pass
6. Request review

## Issue Reporting

Open an issue with:
- What you expected
- What happened
- Steps to reproduce
- macOS version, Xcode version
