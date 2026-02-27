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

## Key File Paths

| Area | Path |
|------|------|
| Panel protocol | `Sources/DevToolsKit/Core/DevToolPanel.swift` |
| Central manager | `Sources/DevToolsKit/Core/DevToolsManager.swift` |
| Config enums | `Sources/DevToolsKit/Core/DevToolsConfiguration.swift` |
| Log provider protocol | `Sources/DevToolsKit/Core/DiagnosticLogProvider.swift` |
| Developer menu | `Sources/DevToolsKit/Menu/DevToolsCommands.swift` |
| Dock modifier | `Sources/DevToolsKit/Modifiers/DevToolsDockModifier.swift` |
| Window managers | `Sources/DevToolsKit/Window/` |
| Performance panel | `Sources/DevToolsKit/Panels/PerformancePanel/` |
| Environment panel | `Sources/DevToolsKit/Panels/EnvironmentPanel/` |
| Data inspector | `Sources/DevToolsKit/Panels/DataInspectorPanel/` |
| Diagnostic export | `Sources/DevToolsKit/Export/` |
| Log store & handler | `Sources/DevToolsKitLogging/` |
| Log panel | `Sources/DevToolsKitLogging/LogPanel.swift` |
| Core tests | `Tests/DevToolsKitTests/` |
| Logging tests | `Tests/DevToolsKitLoggingTests/` |

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

GitHub Flow: Issue → branch `<type>/<issue>-<slug>` → commits → PR → merge to `main`.

## Style

- Swift 6, `@MainActor` on view types, `Sendable` on all public types
- `///` doc comments on all public API
- No force unwraps, no global mutable state
