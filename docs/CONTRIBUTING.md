# Contributing to DevToolsKit

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
Sources/DevToolsKit/
├── Core/          # DevToolPanel protocol, DevToolsManager, config enums
├── Menu/          # DevToolsCommands
├── Modifiers/     # .devToolsDock() modifier
├── Window/        # Standalone + tabbed window managers, dock view
├── Panels/        # Built-in panels (Log, Performance, Environment, DataInspector)
└── Export/        # DiagnosticProvider, DiagnosticReport, exporter
Tests/DevToolsKitTests/  # Unit tests
```

## Adding a New Panel

1. Create a directory: `Sources/DevToolsKit/Panels/YourPanel/`
2. Add a struct conforming to `DevToolPanel` (e.g., `YourPanel.swift`)
3. Add the panel view (e.g., `YourPanelView.swift`)
4. Add `///` doc comments on all public items
5. Add tests in `Tests/DevToolsKitTests/`
6. Update `README.md` built-in panels table if appropriate
7. Run `swift build && swift test`

## Code Style

- **Swift 6** with strict concurrency
- **`@MainActor`** on all view-related types and protocols
- **`Sendable`** conformance on all public types
- **`///` doc comments** on all public items
- Follow existing naming conventions (e.g., `*Panel`, `*PanelView`, `*Provider`)

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
