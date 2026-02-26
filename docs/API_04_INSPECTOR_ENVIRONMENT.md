[< Metrics](API_03_METRICS.md) | [Index](API_00_OVERVIEW.md) | [Export >](API_05_EXPORT.md)

# API Reference: Inspector & Environment

> Source: `Sources/DevToolsKit/Panels/DataInspectorPanel/`, `Sources/DevToolsKit/Panels/EnvironmentPanel/`

## DataInspectorPanel

```swift
public struct DataInspectorPanel: DevToolPanel {
    public let id: String                    // configurable, default "devtools.data-inspector"
    public let title: String                 // configurable, default "Data Inspector"
    public let icon = "eye.circle"
    public let keyboardShortcut: DevToolsKeyboardShortcut?

    public init(
        id: String = "devtools.data-inspector",
        title: String = "Data Inspector",
        dataTitle: String = "Data",
        data: Any,
        keyboardShortcut: DevToolsKeyboardShortcut? = nil
    )
    public func makeBody() -> AnyView
}
```

Configurable panel for inspecting JSON or dictionary data. Multiple instances can coexist with different IDs.

## DataInspectorView

```swift
public struct DataInspectorView: View {
    public init(title: String = "Data", json: Any)
    public init(title: String = "Data", dictionary: [String: Any])
    public var body: some View
}
```

Collapsible tree view. Supports nested dictionaries, arrays, and primitive values. Provides Expand All / Collapse All controls.

## EnvironmentPanel

```swift
public struct EnvironmentPanel: DevToolPanel {
    public let id = "devtools.environment"
    public let title = "Environment"
    public let icon = "gearshape.2"
    public let keyboardShortcut = DevToolsKeyboardShortcut(key: "e")  // ⌘⌥E

    public init()
    public func makeBody() -> AnyView
}
```

Zero-configuration panel displaying system and app environment information.

## EnvironmentPanelView

```swift
public struct EnvironmentPanelView: View {
    public init()
    public var body: some View
}
```

Two-column key-value table with refresh and copy-to-clipboard. Displays macOS version, hardware, memory, thermal state, app metadata, and more.

---

[< Metrics](API_03_METRICS.md) | [Index](API_00_OVERVIEW.md) | [Export >](API_05_EXPORT.md)
