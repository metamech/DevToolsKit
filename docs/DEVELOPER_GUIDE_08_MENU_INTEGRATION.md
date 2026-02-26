[< Diagnostic Export](DEVELOPER_GUIDE_07_DIAGNOSTIC_EXPORT.md) | [Index](DEVELOPER_GUIDE_00_OVERVIEW.md) | [Testing >](DEVELOPER_GUIDE_09_TESTING.md)

# Developer Guide: Menu Integration

`DevToolsCommands` generates a "Developer" menu that provides keyboard-shortcut access to all registered panels.

## Setup

```swift
var body: some Scene {
    WindowGroup { ... }
    .commands {
        DevToolsCommands(manager: devTools)
    }
}
```

## Menu Structure

The generated Developer menu contains:

1. **Panel entries** — One button per registered panel, with keyboard shortcut if defined
2. **Divider**
3. **Show All (Tabbed)** — Sets all panels to tabbed mode and opens the tabbed window (⌘⌥⇧D)
4. **Divider**
5. **Export Diagnostics...** — Triggers the diagnostic export flow
6. **Divider**
7. **Log Level** — Picker with Debug / Info / Warning / Error
8. **Divider**
9. **Developer Mode** — Toggle

## Customization

### Custom Window Managers

If you need to share window manager instances across your app:

```swift
let windowManager = DevToolsWindowManager()
let tabbedWindow = DevToolsTabbedWindow()

DevToolsCommands(
    manager: devTools,
    windowManager: windowManager,
    tabbedWindow: tabbedWindow
)
```

### Custom Export Handler

Override the default NSSavePanel-based export:

```swift
DevToolsCommands(manager: devTools, onExportDiagnostics: {
    // Send to analytics, upload to server, etc.
})
```

## Conditional Display

Show the Developer menu only when developer mode is enabled:

```swift
.commands {
    if devTools.isDeveloperMode {
        DevToolsCommands(manager: devTools)
    }
}
```

---

[< Diagnostic Export](DEVELOPER_GUIDE_07_DIAGNOSTIC_EXPORT.md) | [Index](DEVELOPER_GUIDE_00_OVERVIEW.md) | [Testing >](DEVELOPER_GUIDE_09_TESTING.md)
