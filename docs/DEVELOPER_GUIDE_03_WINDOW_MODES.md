[< Panel System](DEVELOPER_GUIDE_02_PANEL_SYSTEM.md) | [Index](DEVELOPER_GUIDE_00_OVERVIEW.md) | [Log Panel >](DEVELOPER_GUIDE_04_LOG_PANEL.md)

# Developer Guide: Window Modes

Each panel can be displayed in one of three modes. The mode is persisted per-panel to `UserDefaults`.

## Standalone

Each panel gets its own `NSWindow` with frame autosave. Managed by `DevToolsWindowManager`.

```swift
devTools.setDisplayMode(.standalone, for: "devtools.log")
devTools.openPanel("devtools.log")  // Opens in its own window
```

Window features:
- Titled, closable, resizable, miniaturizable
- Frame position remembered via `NSWindow.setFrameAutosaveName`
- Separate from the standard macOS Window menu

## Tabbed

All tabbed panels share a single window with a horizontal tab bar. Managed by `DevToolsTabbedWindow`.

```swift
devTools.setDisplayMode(.tabbed, for: "devtools.log")
devTools.openPanel("devtools.log")  // Opens in the tabbed window
```

Tab features:
- Horizontal scrolling tab bar
- Context menu on each tab: "Pop Out to Window", "Move to Dock", "Close"
- Active tab persisted in `DevToolsManager.activeTabbedPanelID`
- "Show All (Tabbed)" menu item sets all panels to tabbed mode (⌘⌥⇧D)

## Docked

Panels dock to the edge of your app content via the `.devToolsDock(_:)` modifier, using a split view.

```swift
devTools.setDisplayMode(.docked, for: "devtools.log")
devTools.openPanel("devtools.log")  // Shows in the dock
```

Dock features:
- Position: bottom (default), right, or left — controlled via `dockPosition`
- Resizable via the split view divider
- Dock size persisted to `UserDefaults`
- Toolbar with position picker, pop-out button, and close button
- Tab bar for switching between docked panels
- Context menu: "Pop Out to Window", "Move to Tabbed View"

## Transitions

Users can move panels between modes via context menus, or programmatically:

```swift
devTools.movePanel("devtools.log", to: .docked)
```

This closes the panel in its current mode and reopens it in the target mode.

---

[< Panel System](DEVELOPER_GUIDE_02_PANEL_SYSTEM.md) | [Index](DEVELOPER_GUIDE_00_OVERVIEW.md) | [Log Panel >](DEVELOPER_GUIDE_04_LOG_PANEL.md)
