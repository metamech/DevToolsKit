# API Reference: Core

> Source: `Sources/DevToolsKit/Core/`

## DevToolPanel

```swift
@MainActor
public protocol DevToolPanel: Identifiable, Sendable where ID == String {
    var id: String { get }
    var title: String { get }
    var icon: String { get }
    var keyboardShortcut: DevToolsKeyboardShortcut? { get }  // default: nil
    var preferredSize: CGSize { get }                        // default: 700×500
    var minimumSize: CGSize { get }                          // default: 400×300
    func makeBody() -> AnyView
}
```

Protocol every panel must conform to. Panels are value types that describe themselves and produce a view. See [Panel System](DEVELOPER_GUIDE_02_PANEL_SYSTEM.md).

## DevToolsKeyboardShortcut

```swift
public struct DevToolsKeyboardShortcut: Sendable {
    public let key: Character
    public let modifiers: EventModifiers
    public init(key: Character, modifiers: EventModifiers = [.command, .option])
}
```

Keyboard shortcut definition. Default modifiers are Command+Option.

## DevToolsManager

```swift
@MainActor @Observable
public final class DevToolsManager: Sendable {
    // Init
    public init(keyPrefix: String)

    // Properties
    public let keyPrefix: String
    public private(set) var panels: [any DevToolPanel]
    public var isDeveloperMode: Bool                    // persisted
    public var logLevel: DevToolsLogLevel               // persisted
    public private(set) var panelDisplayModes: [String: PanelDisplayMode]
    public var dockPosition: DockPosition               // persisted
    public var isDockVisible: Bool                      // persisted
    public var dockSize: CGFloat                        // persisted
    public var activeDockPanelID: String?               // persisted
    public var activeTabbedPanelID: String?
    public var isTabbedWindowOpen: Bool
    public var openStandalonePanelIDs: Set<String>
    public private(set) var diagnosticProviders: [any DiagnosticProvider]

    // Panel registration
    public func register(_ panel: any DevToolPanel)
    public func unregister(panelID: String)
    public func panel(for id: String) -> (any DevToolPanel)?

    // Display modes
    public func setDisplayMode(_ mode: PanelDisplayMode, for panelID: String)
    public func displayMode(for panelID: String) -> PanelDisplayMode

    // Panel lifecycle
    public func openPanel(_ panelID: String)
    public func closePanel(_ panelID: String)
    public func movePanel(_ panelID: String, to mode: PanelDisplayMode)

    // Diagnostics
    public func registerDiagnosticProvider(_ provider: any DiagnosticProvider)
}
```

Central registry and state manager. All persisted properties use UserDefaults under the `keyPrefix` namespace. See [Quick Start](DEVELOPER_GUIDE_01_QUICK_START.md).

## PanelDisplayMode

```swift
public enum PanelDisplayMode: String, Codable, Sendable {
    case standalone  // Own NSWindow
    case tabbed      // Shared tabbed window
    case docked      // App content dock
}
```

## DockPosition

```swift
public enum DockPosition: String, Codable, Sendable, CaseIterable {
    case bottom, right, left
}
```

## DevToolsLogLevel

```swift
public enum DevToolsLogLevel: String, CaseIterable, Sendable, Codable, Comparable {
    case debug, info, warning, error
    public var displayName: String
}
```

Severity levels ordered from least to most severe. Supports `Comparable`.

## Environment Extension

```swift
extension EnvironmentValues {
    public var devToolsManager: DevToolsManager?
}

extension View {
    public func environment(_ manager: DevToolsManager) -> some View
}
```
