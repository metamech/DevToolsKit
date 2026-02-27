# Contributing to DevToolsKit

[Index](INDEX.md)

## Prerequisites

- macOS 15+
- Xcode 16+
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
└── DevToolsKitLicensingStoreKit/ # StoreKit backend
```

## Adding a New Panel

1. Create a directory under the appropriate module's `Panels/`
2. Add a struct conforming to `DevToolPanel` (e.g., `YourPanel.swift`)
3. Add the panel view (e.g., `YourPanelView.swift`)
4. Add `///` doc comments on all public items
5. Add tests in the corresponding `Tests/` directory
6. Update docs under `docs/` for the relevant module
7. Run `swift build && swift test`

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
