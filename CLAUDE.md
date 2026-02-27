# DevToolsKit — AI Assistant Instructions

## Project

Swift package: in-app developer tools for macOS SwiftUI apps.
Platform: macOS 15+, Swift 6, strict concurrency.

Multi-product package:
- **DevToolsKit** — core (no external deps): panels, manager, export, window/menu
- **DevToolsKitLogging** — logging (depends on DevToolsKit + swift-log): log store, handler, panel

## Build & Test

```bash
swift build            # both targets
swift test             # 35 tests in 5 suites
swift-format lint --recursive Sources/ Tests/
swiftlint lint
```

## Architecture

- `DevToolsManager` (@Observable, @MainActor) is the central registry
- Panels conform to `DevToolPanel` protocol — value types with `makeBody() -> AnyView`
- Three display modes: standalone NSWindow, tabbed NSWindow, docked split view
- State persisted to UserDefaults under configurable `keyPrefix`
- `DiagnosticLogProvider` protocol decouples exporter from concrete log store
- `DevToolsLogStore` conforms to `DiagnosticLogProvider` in the logging target
- swift-log integration via `DevToolsLogHandler` → `DevToolsLogStore`
- Diagnostic export via `DiagnosticProvider` protocol → JSON

## Naming Conventions

- Panels: `FooPanel` struct + `FooPanelView` view
- Providers: `FooProvider` conforming to `MetricsProvider` or `DiagnosticProvider`
- Panel IDs: `"devtools.foo"` for built-in, `"namespace.foo"` for custom
- UserDefaults keys: `"{keyPrefix}.{suffix}"`

## Common Tasks

### Add a built-in panel (core)
1. Create `Sources/DevToolsKit/Panels/FooPanel/FooPanel.swift` + `FooPanelView.swift`
2. Conform to `DevToolPanel`, set id/title/icon/shortcut
3. Add `///` doc comments on all public items
4. Add tests in `Tests/DevToolsKitTests/`

### Add a diagnostic provider
1. Conform to `DiagnosticProvider` (sectionName + collect())
2. Register with `manager.registerDiagnosticProvider(_:)`

### Modify DevToolsManager
- Persisted properties use `access(keyPath:)` / `withMutation(keyPath:)` + UserDefaults
- Use `key(_:)` helper for prefixed keys

## Workflow

## Workflow Rules

- Always read this CLAUDE.md before making significant changes.
- Before starting work, propose a concrete plan and ask for approval.
- Keep a running log in `claude-progress.md`:
  - What was planned.
  - What was completed.
  - Design decisions and trade-offs made.
- Do not change without explicit approval:
  - Bundle identifier.
  - Entitlements (especially app sandbox setting).
  - Signing configuration.
  - Deployment targets.
- Follow a "GitHub Flow"
  - Work must be associated with a GitHub Issue. If one doesn't exist, create one.
  - Create a feature branch before any implementation: `<type>/<issue-number>-<slug>`.
  - Commit and push work to feature branch at each major phase of the plan
  - Update PROGRESS.md if present and applicable when starting and after completing each phase
  - Create a PR to merge into "main" when the plan is completed and wait for user input
  - After the PR is approved perform "clean up" to prepare for new work:
    - squash-merge the PR main
    - delete feature branch (remote & local)
    - checkout and pull main


## Style

- Swift 6, `@MainActor` on view types, `Sendable` on all public types
- `///` doc comments on all public API
- No force unwraps, no global mutable state
