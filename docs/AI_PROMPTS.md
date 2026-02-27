# AI Coding Assistant Prompts

[Index](INDEX.md)

Template prompts for AI coding assistants integrating DevToolsKit.

## Adding a Custom Panel (Core)

> Add a DevToolPanel called **{Name}Panel** to my app.
> - Panel ID: `"{namespace}.{slug}"`
> - SF Symbol: `"{icon}"`
> - Keyboard shortcut: ⌘⌥{key}
> - The panel should display: {description}
>
> Follow the DevToolsKit pattern: struct conforming to `DevToolPanel`, separate `{Name}PanelView`, register with `DevToolsManager`.

## Adding a MetricsProvider (Core)

> Create a `MetricsProvider` for the Performance panel.
> - Collect these metrics: {list metrics, units, and sources}
> - Group them by: {group names}
> - Use appropriate `MetricColor` values.
>
> Follow the DevToolsKit pattern: conform to `MetricsProvider`, return `[MetricGroup]` from `currentMetrics()`.

## Adding a DiagnosticProvider (Core)

> Create a `DiagnosticProvider` that exports {description}.
> - Section name: `"{name}"`
> - Data shape: {describe the Codable structure}
>
> Register with `manager.registerDiagnosticProvider(...)`.

## Integrating Logging (DevToolsKitLogging)

> Add swift-log integration to my app using DevToolsKitLogging.
> - Create `DevToolsLogStore` and `DevToolsLogHandler`
> - Bootstrap `LoggingSystem`
> - Register `LogPanel` with the manager
> - Include logs in diagnostic export

## Integrating Metrics (DevToolsKitMetrics)

> Add swift-metrics integration to my app using DevToolsKitMetrics.
> - Create `InMemoryMetricsStorage` and `MetricsManager`
> - Bootstrap `MetricsSystem` with `DevToolsMetricsFactory`
> - Register `MetricsPanel` with the manager
> - Register `MetricsManager` as a diagnostic provider

## Adding Feature Flags (DevToolsKitLicensing)

> Set up feature flags in my app using DevToolsKitLicensing.
> - Flags: {list flag IDs, names, categories, default states}
> - License tier requirements: {which flags are gated}
> - Rollouts: {percentage rollout specs if any}
> - Register `FeatureFlagsPanel` with the manager

## Debugging Tips

**Panels not showing in menu?**
- Verify `manager.register(panel)` was called
- Check that `DevToolsCommands(manager:)` is in `.commands {}`
- Ensure the panel ID is unique

**Log entries not appearing?**
- `LoggingSystem.bootstrap` must be called before any `Logger` usage
- Wait for `Task { @MainActor }` dispatch (~50ms in tests)
- Check `logStore.filterLevel` isn't filtering them out

**Metrics not recording?**
- `MetricsSystem.bootstrap` must be called before creating any `Counter`/`Timer`/etc.
- Handlers dispatch via `Task { @MainActor }` — entries appear asynchronously
- Check `metricsManager.totalEntries` to verify data is flowing

**Feature flags always disabled?**
- Check `licensing.flagState(for:)?.isGated` — may need an active license
- Verify flag was registered with `registerFlag` / `registerFlags`
- Check for expired TTL overrides
