# Window Modes

[< Panels](PANELS.md) | [Index](../INDEX.md) | [Export >](EXPORT.md)

> **Module:** `DevToolsKit`

Panels can display in three modes. Change at runtime via `movePanel(_:to:)` or context menus.

## Standalone

Each panel gets its own `NSWindow` with frame autosave.

```swift
manager.openPanel("devtools.environment")
// or
manager.setDisplayMode(.standalone, for: "devtools.environment")
manager.openPanel("devtools.environment")
```

## Tabbed

Multiple panels share a single window with a horizontal tab bar. Open with **⌘⌥⇧D** or:

```swift
manager.setDisplayMode(.tabbed, for: "myapp.debug")
manager.openPanel("myapp.debug")
```

Context menu per tab: Pop Out to Standalone, Move to Dock, Close.

## Docked

Panels appear in a split view alongside your app content via the `.devToolsDock(_:)` modifier.

```swift
ContentView()
    .devToolsDock(manager)
```

Configure dock position and visibility:

```swift
manager.dockPosition = .bottom   // .bottom, .right, .left
manager.isDockVisible = true
```

The dock toolbar includes a position picker, pop-out button, and close button. Multiple docked panels show a tab bar.

## Transitions

```swift
manager.movePanel("devtools.log", to: .standalone)  // Dock → Standalone
manager.movePanel("devtools.log", to: .tabbed)      // Standalone → Tabbed
manager.movePanel("devtools.log", to: .docked)       // Tabbed → Dock
```

## Persistence

Display modes, dock position, dock visibility, and active panel selections persist to `UserDefaults` under keys prefixed with the manager's `keyPrefix`.
