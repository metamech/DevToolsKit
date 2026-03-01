# DevToolsKit — AI Assistant Instructions

## Project

Swift package: in-app developer tools for macOS SwiftUI apps.
Platform: macOS 15+, Swift 6, strict concurrency.

Multi-product package:
- **DevToolsKit** — core (no external deps): panels, manager, export, window/menu
- **DevToolsKitLogging** — logging (depends on DevToolsKit + swift-log): log store, handler, panel
- **DevToolsKitMetrics** — metrics (depends on DevToolsKit + swift-metrics): storage, query, factory, panel
- **DevToolsKitLicensing** — feature flags & licensing (depends on DevToolsKit + swift-metrics): flags, experiments, license gating, panel
- **DevToolsKitLicensingSeat** — LicenseSeat backend (depends on DevToolsKitLicensing + licenseseat-swift)
- **DevToolsKitLicensingStoreKit** — StoreKit backend (depends on DevToolsKitLicensing)
- **DevToolsKitProcess** — process execution (no external deps): executor, result, timeout
- **DevToolsKitSecurity** — security (depends on DevToolsKit): permissions, sandbox, bookmarks, command policy, panel
- **DevToolsKitGitHub** — GitHub API (depends on DevToolsKit): client, cache, retry, types, panel
- **DevToolsKitDiff** — diff engine (no external deps): unified diff parsing, application, validation

## Build & Test

```bash
swift build            # all targets
swift test             # all tests
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
- swift-metrics integration via `DevToolsMetricsFactory` → `InMemoryMetricsStorage`
- Feature flags via `LicensingManager` with cohorts, rollouts, targeting, license-tier gating
- Diagnostic export via `DiagnosticProvider` protocol → JSON
- Handlers (log, metrics) dispatch to @MainActor storage via `Task { @MainActor in }`

## Naming Conventions

- Panels: `FooPanel` struct + `FooPanelView` view
- Providers: `FooProvider` conforming to `MetricsProvider` or `DiagnosticProvider`
- Handlers: `DevToolsFooHandler` — `@unchecked Sendable`, dispatches to storage
- Panel IDs: `"devtools.foo"` for built-in, `"namespace.foo"` for custom
- UserDefaults keys: `"{keyPrefix}.{suffix}"`

## Common Tasks

### Add a built-in panel (core)
1. Create `Sources/DevToolsKit/Panels/FooPanel/FooPanel.swift` + `FooPanelView.swift`
2. Conform to `DevToolPanel`, set id/title/icon/shortcut
3. Add `///` doc comments on all public items
4. Add tests in `Tests/DevToolsKitTests/`

### Add a panel in an opt-in module
1. Create under `Sources/DevToolsKitFoo/Panels/BarPanel/`
2. Same pattern as core panels but `import DevToolsKit` for the protocol
3. Add tests in `Tests/DevToolsKitFooTests/`

### Add a diagnostic provider
1. Conform to `DiagnosticProvider` (sectionName + collect())
2. Register with `manager.registerDiagnosticProvider(_:)`

### Modify DevToolsManager
- Persisted properties use `access(keyPath:)` / `withMutation(keyPath:)` + UserDefaults
- Use `key(_:)` helper for prefixed keys

## Documentation Rules

**Always update docs when changing code.** Documentation lives in `docs/` organized by module:

```
docs/
├── INDEX.md                  # Master navigation (update when adding modules/docs)
├── core/                     # DevToolsKit
│   ├── API.md, QUICK_START.md, PANELS.md, WINDOW_MODES.md, EXPORT.md, MENU.md
├── logging/                  # DevToolsKitLogging
│   ├── API.md, GUIDE.md
├── metrics/                  # DevToolsKitMetrics
│   ├── API.md, GUIDE.md
├── licensing/                # DevToolsKitLicensing
│   ├── API.md, FEATURE_FLAGS.md, EXPERIMENTATION.md, LICENSE_BACKENDS.md
├── process/                  # DevToolsKitProcess
│   ├── API.md, GUIDE.md
├── security/                 # DevToolsKitSecurity
│   ├── API.md, GUIDE.md
├── github/                   # DevToolsKitGitHub
│   ├── API.md, GUIDE.md
├── TESTING.md, AI_PROMPTS.md, CONTRIBUTING.md
```

When making changes:
- **Adding a feature**: Update the module's GUIDE.md and API.md. Add version annotation (e.g., "Since 0.x.0") for new public types. Update AI_PROMPTS.md if the feature introduces a new integration pattern.
- **Adding a module**: Create a `docs/{module}/` directory with at least API.md and GUIDE.md. Add the module to INDEX.md, README.md, and this file's module list.
- **Modifying a feature**: Update affected docs to reflect the current implementation.
- **Keep each document short**: 2–3 pages max. Break long topics into separate files.
- **Navigation**: Every doc file (except INDEX.md) has breadcrumb links: `[< Previous](file) | [Index](../INDEX.md) | [Next >](file)`
- **API docs**: Start with `> Source: path/to/source/` and `> Since: X.Y.Z`. Show full Swift 6 annotations.
- **README.md**: Keep the modules table, panels table, and documentation links current.

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
