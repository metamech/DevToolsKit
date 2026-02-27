# Panel System

[< Quick Start](QUICK_START.md) | [Index](../INDEX.md) | [Window Modes >](WINDOW_MODES.md)

> **Module:** `DevToolsKit`

## The DevToolPanel Protocol

Every panel is a value-type struct conforming to `DevToolPanel`:

```swift
@MainActor
public protocol DevToolPanel: Identifiable, Sendable where ID == String {
    var id: String { get }
    var title: String { get }
    var icon: String { get }                             // SF Symbol name
    var keyboardShortcut: DevToolsKeyboardShortcut? { get }  // default: nil
    var preferredSize: CGSize { get }                    // default: 700×500
    var minimumSize: CGSize { get }                      // default: 400×300
    func makeBody() -> AnyView
}
```

## Built-in Panels (Core)

| Panel | ID | Shortcut | Description |
|-------|----|----------|-------------|
| `EnvironmentPanel` | `devtools.environment` | ⌘⌥E | System info: macOS, hardware, memory, thermal state |
| `PerformancePanel` | `devtools.performance` | ⌘⌥M | Card-based metric dashboard from `MetricsProvider` |
| `DataInspectorPanel` | configurable | configurable | Collapsible JSON/dictionary tree view |

Panels from opt-in modules:

| Panel | Module | ID | Shortcut |
|-------|--------|----|----------|
| `LogPanel` | DevToolsKitLogging | `devtools.log` | ⌘⌥L |
| `MetricsPanel` | DevToolsKitMetrics | `devtools.metrics` | ⌘⌥I |
| `FeatureFlagsPanel` | DevToolsKitLicensing | `devtools.feature-flags` | ⌘⌥F |

## Creating a Custom Panel

```swift
public struct AgentConfigPanel: DevToolPanel {
    public let id = "myapp.agent-config"
    public let title = "Agent Config"
    public let icon = "gearshape.2"
    public let keyboardShortcut = DevToolsKeyboardShortcut(key: "a")

    public func makeBody() -> AnyView {
        AnyView(AgentConfigView())
    }
}
```

Register it: `manager.register(AgentConfigPanel())`

## Panel ID Conventions

- Built-in: `"devtools.foo"`
- Custom: `"namespace.foo"` (e.g., `"myapp.debug"`)

## Keyboard Shortcuts

`DevToolsKeyboardShortcut(key:modifiers:)` defaults to **⌘⌥** + key. Override modifiers for custom combos:

```swift
DevToolsKeyboardShortcut(key: "d", modifiers: [.command, .shift])
```

## Panel Lifecycle

```swift
manager.register(panel)                    // Add to registry
manager.openPanel(panelID)                 // Open in current display mode
manager.closePanel(panelID)                // Close
manager.movePanel(panelID, to: .docked)    // Change display mode
manager.unregister(panelID: id)            // Remove from registry
```
