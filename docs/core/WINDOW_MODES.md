# Window Modes

[< Panels](PANELS.md) | [Index](../INDEX.md) | [Export >](EXPORT.md)

> **Module:** `DevToolsKit`
> **Since:** 0.4.0 (global display mode)

All panels share a single global display mode controlled by `manager.displayMode`. Individual panels can be "popped out" to standalone windows without changing the global mode.

## Display Modes

### Docked

Panels appear in a split view alongside your app content via the `.devToolsDock(_:)` modifier.

```swift
manager.displayMode = .docked

ContentView()
    .devToolsDock(manager)
```

Configure dock position and visibility:

```swift
manager.dockPosition = .bottom   // .bottom, .right, .left
manager.isDockVisible = true
```

The dock toolbar includes a position picker, pop-out button, and close button. All registered panels appear as tabs in the dock.

### Windowed (default)

All panels share a single tabbed `NSWindow`. This is the default mode.

```swift
manager.displayMode = .windowed
manager.openPanel("devtools.log")
```

Open all panels at once with **⌘⌥⇧D** or programmatically:

```swift
for panel in manager.panels {
    manager.openPanel(panel.id)
}
```

### Separate Windows

Each panel opens in its own standalone `NSWindow` with frame autosave.

```swift
manager.displayMode = .separateWindows
manager.openPanel("devtools.environment")
```

## Pop Out

Pop a panel into a standalone window without changing the global mode:

```swift
manager.popOutPanel("devtools.log")  // Opens standalone window
manager.closePopOut("devtools.log")  // Closes the standalone window
```

Context menus in the tab bar and dock include "Pop Out to Window".

## Mode Switching

Change the global mode at runtime. The Developer menu includes a Display Mode picker:

```swift
manager.displayMode = .docked          // Switch to dock
manager.displayMode = .windowed        // Switch to tabbed window
manager.displayMode = .separateWindows // Switch to individual windows
```

## Persistence

The global display mode, dock position, dock visibility, and active panel selections persist to `UserDefaults` under keys prefixed with the manager's `keyPrefix`.

## Migration from Per-Panel Modes

Pre-0.4.0 versions used per-panel display modes (`.standalone`, `.tabbed`, `.docked`). On first launch after upgrading, the manager automatically migrates:

- Scans `{prefix}.panelMode.*` UserDefaults keys
- Maps the dominant per-panel mode to the new global mode (tabbed → windowed, docked → docked, standalone → separateWindows)
- Cleans up legacy keys
