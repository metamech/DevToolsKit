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
| *{Panel Title}* | ⌘⌥{key} | Opens panel in current global display mode |
| — divider — | | |
| Display Mode | | Picker: Docked, Windowed, Separate Windows |
| Show All | ⌘⌥⇧D | Opens all panels in current mode |
| — divider — | | |
| Export Diagnostics... | | Saves JSON diagnostic report |
| — divider — | | |
| Log Level | | Submenu: Trace, Debug, Info, Warning, Error |
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

## Custom Export Handler

```swift
DevToolsCommands(manager: manager, onExportDiagnostics: {
    // Custom export action instead of default NSSavePanel
})
```
