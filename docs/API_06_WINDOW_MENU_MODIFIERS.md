[< Export](API_05_EXPORT.md) | [Index](API_00_OVERVIEW.md)

# API Reference: Window, Menu & Modifiers

> Source: `Sources/DevToolsKit/Window/`, `Sources/DevToolsKit/Menu/`, `Sources/DevToolsKit/Modifiers/`

## DevToolsWindowManager

```swift
@MainActor
public final class DevToolsWindowManager {
    public init()

    public func open(panel: any DevToolPanel)
    public func close(panelID: String)
    public func isOpen(panelID: String) -> Bool
    public func closeAll()
}
```

Manages standalone `NSWindow` instances for panels. Each window has frame autosave keyed by `"DevTools.\(panel.id)"`.

## DevToolsTabbedWindow

```swift
@MainActor
public final class DevToolsTabbedWindow {
    public init()

    public func open(manager: DevToolsManager)
    public func close()
    public var isOpen: Bool
}
```

Manages a single shared tabbed window. The tab bar shows all panels with display mode `.tabbed`. Frame autosaved as `"DevTools.TabbedWindow"`.

## DevToolsCommands

```swift
public struct DevToolsCommands: Commands {
    public init(
        manager: DevToolsManager,
        windowManager: DevToolsWindowManager = DevToolsWindowManager(),
        tabbedWindow: DevToolsTabbedWindow = DevToolsTabbedWindow(),
        onExportDiagnostics: (() -> Void)? = nil
    )

    public var body: some Commands
}
```

SwiftUI `Commands` that generate a "Developer" menu. Contains panel entries with shortcuts, "Show All (Tabbed)" (⌘⌥⇧D), "Export Diagnostics...", log level picker, and developer mode toggle.

## .devToolsDock(_:)

```swift
extension View {
    public func devToolsDock(_ manager: DevToolsManager) -> some View
}
```

View modifier that wraps content in a resizable split view (HSplitView or VSplitView) when `manager.isDockVisible` is true. Dock position is controlled by `manager.dockPosition`. When the dock is hidden, the modifier passes through the content unchanged.

---

[< Export](API_05_EXPORT.md) | [Index](API_00_OVERVIEW.md)
