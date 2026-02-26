[< Testing](DEVELOPER_GUIDE_09_TESTING.md) | [Index](DEVELOPER_GUIDE_00_OVERVIEW.md)

# Developer Guide: AI Prompts

Recommended prompts for AI coding assistants (Claude Code, GitHub Copilot, etc.) when working with DevToolsKit.

## Adding a Custom Panel

> "Create a new DevToolPanel conformance called `[Name]Panel` in `Sources/DevToolsKit/Panels/[Name]Panel/`. It should have id `devtools.[name]`, title `[Title]`, icon `[SF Symbol]`, and shortcut ⌘⌥[Key]. The view should display [description]. Add it to the built-in panels table in README.md."

## Adding a Metrics Provider

> "Implement a `MetricsProvider` that collects [describe metrics]. Return `MetricGroup` instances with appropriate `MetricColor` values. The provider should be `@MainActor` and `Sendable`."

## Adding a Diagnostic Provider

> "Create a `DiagnosticProvider` with section name `[name]` that collects [describe data]. The `collect()` method should return a `Codable & Sendable` struct. Register it with `DevToolsManager.registerDiagnosticProvider(_:)`."

## Extending the Manager

> "Add a new capability to `DevToolsManager`: [describe feature]. Follow the existing pattern of UserDefaults persistence with the `key(_:)` prefix method. Use `@Observable` access/mutation tracking for properties that need SwiftUI reactivity."

## Integrating in a Host App

> "Integrate DevToolsKit into [app name]. Create a `DevToolsManager` with key prefix `[prefix]`, register `LogPanel`, `PerformancePanel` (with a custom provider for [metrics]), and `EnvironmentPanel`. Attach `.devToolsDock()` to the main content view and add `DevToolsCommands` to the scene."

## Debugging Tips

> "The DevToolsKit panels aren't showing up."
>
> Check: (1) panels are registered before the view body is evaluated, (2) `.devToolsDock()` is attached to the content view, (3) `DevToolsCommands` is in `.commands { }`, (4) `isDeveloperMode` is `true` if you're conditionally showing the menu.

> "Log entries aren't appearing."
>
> Check: (1) `LoggingSystem.bootstrap` was called before any `Logger` usage, (2) the `DevToolsLogHandler` was given the same `DevToolsLogStore` instance as the `LogPanel`, (3) the filter level isn't set higher than the log level of the entries.

---

[< Testing](DEVELOPER_GUIDE_09_TESTING.md) | [Index](DEVELOPER_GUIDE_00_OVERVIEW.md)
