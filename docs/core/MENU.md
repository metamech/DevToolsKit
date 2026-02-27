# Menu Integration

[< Export](EXPORT.md) | [Index](../INDEX.md) | [API Reference >](API.md)

> **Module:** `DevToolsKit`

## Setup

```swift
.commands {
    DevToolsCommands(manager: manager)
}
```

## Generated Menu Structure

The **Developer** menu auto-generates entries from registered panels:

| Item | Shortcut | Action |
|------|----------|--------|
| *{Panel Title}* | ⌘⌥{key} | Opens panel in its current display mode |
| — divider — | | |
| Show All (Tabbed) | ⌘⌥⇧D | Opens tabbed window with all panels |
| — divider — | | |
| Export Diagnostics... | | Saves JSON diagnostic report |
| — divider — | | |
| Log Level | | Submenu: Debug, Info, Warning, Error |
| Developer Mode | | Toggle on/off |

## Conditional Display

Show the Developer menu only in developer mode:

```swift
.commands {
    if manager.isDeveloperMode {
        DevToolsCommands(manager: manager)
    }
}
```

## Custom Window Manager

Share a window manager to coordinate standalone windows:

```swift
let windowManager = DevToolsWindowManager()
DevToolsCommands(
    manager: manager,
    windowManager: windowManager,
    tabbedWindow: DevToolsTabbedWindow()
)
```

## Custom Export Handler

```swift
DevToolsCommands(manager: manager, onExportDiagnostics: {
    // Custom export action instead of default NSSavePanel
})
```
