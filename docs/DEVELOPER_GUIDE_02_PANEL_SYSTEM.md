# Developer Guide: Panel System

## The DevToolPanel Protocol

Every panel conforms to `DevToolPanel`:

```swift
@MainActor
public protocol DevToolPanel: Identifiable, Sendable where ID == String {
    var id: String { get }
    var title: String { get }
    var icon: String { get }                            // SF Symbol name
    var keyboardShortcut: DevToolsKeyboardShortcut? { get }  // default: nil
    var preferredSize: CGSize { get }                   // default: 700×500
    var minimumSize: CGSize { get }                     // default: 400×300
    func makeBody() -> AnyView
}
```

## Creating a Custom Panel

```swift
struct AgentConfigPanel: DevToolPanel {
    let id = "myapp.agent-config"
    let title = "Agent Config"
    let icon = "gearshape"
    let keyboardShortcut = DevToolsKeyboardShortcut(key: "a")
    let preferredSize = CGSize(width: 600, height: 400)
    let minimumSize = CGSize(width: 400, height: 300)

    func makeBody() -> AnyView {
        AnyView(AgentConfigView())
    }
}
```

Register it:

```swift
devTools.register(AgentConfigPanel())
```

## Panel IDs

IDs must be unique and stable across app launches — they're used as keys for persisted display mode preferences. Convention: `"namespace.panel-name"`.

Built-in IDs:
- `devtools.log`
- `devtools.performance`
- `devtools.environment`
- `devtools.data-inspector` (default; configurable)

## Keyboard Shortcuts

`DevToolsKeyboardShortcut` defaults to Command+Option:

```swift
// ⌘⌥A
DevToolsKeyboardShortcut(key: "a")

// ⌘⇧A (custom modifiers)
DevToolsKeyboardShortcut(key: "a", modifiers: [.command, .shift])
```

## Panel Lifecycle

- `register(_:)` — Add to the manager's registry
- `openPanel(_:)` — Open in the panel's current display mode
- `closePanel(_:)` — Close across all display modes
- `movePanel(_:to:)` — Close and reopen in a different display mode
- `unregister(panelID:)` — Remove from registry and clear persisted preferences
