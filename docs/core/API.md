# Core API Reference

[< Menu](MENU.md) | [Index](../INDEX.md)

> **Source:** `Sources/DevToolsKit/`
> **Since:** 0.1.0

## DevToolPanel

```swift
@MainActor
public protocol DevToolPanel: Identifiable, Sendable where ID == String {
    var id: String { get }
    var title: String { get }
    var icon: String { get }
    var keyboardShortcut: DevToolsKeyboardShortcut? { get }  // default: nil
    var preferredSize: CGSize { get }   // default: 700×500
    var minimumSize: CGSize { get }     // default: 400×300
    func makeBody() -> AnyView
}
```

## DevToolsKeyboardShortcut

```swift
public struct DevToolsKeyboardShortcut: Sendable {
    public let key: Character
    public let modifiers: EventModifiers  // default: [.command, .option]
}
```

## DevToolsManager

```swift
@MainActor @Observable
public final class DevToolsManager: Sendable {
    public init(keyPrefix: String = "devtools")

    // Panel registry
    public private(set) var panels: [any DevToolPanel]
    public func register(_ panel: any DevToolPanel)
    public func unregister(panelID: String)
    public func panel(for id: String) -> (any DevToolPanel)?

    // Global display mode (since 0.4.0)
    public var displayMode: DevToolsDisplayMode   // default: .windowed
    public func openPanel(_ panelID: String)
    public func closePanel(_ panelID: String)
    public func popOutPanel(_ panelID: String)    // standalone without changing global mode
    public func closePopOut(_ panelID: String)

    // Settings (persisted to UserDefaults)
    public var isDeveloperMode: Bool
    public var logLevel: DevToolsLogLevel
    public var dockPosition: DockPosition
    public var isDockVisible: Bool
    public var dockSize: CGFloat
    public var activeDockPanelID: String?
    public var activeTabbedPanelID: String?
    public var isTabbedWindowOpen: Bool
    public var openStandalonePanelIDs: Set<String>

    // Diagnostic providers
    public private(set) var diagnosticProviders: [any DiagnosticProvider]
    public func registerDiagnosticProvider(_ provider: any DiagnosticProvider)
}
```

## Enums

```swift
public enum DevToolsDisplayMode: String, Sendable, Codable, CaseIterable {  // since 0.4.0
    case docked, windowed, separateWindows
}

public enum DockPosition: String, Sendable, Codable {
    case bottom, right, left
}

public enum DevToolsLogLevel: String, Sendable, Codable, Comparable, CaseIterable {
    case trace, debug, info, warning, error
}
```

## DiagnosticProvider

```swift
@MainActor
public protocol DiagnosticProvider {
    var sectionName: String { get }
    func collect() async -> any Codable & Sendable
}
```

## DiagnosticExporter

```swift
@MainActor
public struct DiagnosticExporter {
    public init(manager: DevToolsManager, logStore: (any DiagnosticLogProvider)? = nil, appName: String? = nil)
    public func export() async          // macOS only — presents NSSavePanel
    public func exportData() async -> Data?  // all platforms (since 0.4.0)
}
```

## DiagnosticReport

```swift
public struct DiagnosticReport: Codable, Sendable {
    public let appName, appVersion, macOSVersion: String
    public let hardware: HardwareInfo
    public let developerSettings: DeveloperSettingsSnapshot
    public let recentLogEntries: [LogEntrySnapshot]
    public let customSections: [String: AnyCodable]
    public let timestamp: Date
}
```

## Built-in Panels

```swift
public struct EnvironmentPanel: DevToolPanel     // "devtools.environment", ⌘⌥E
public struct PerformancePanel: DevToolPanel      // "devtools.performance", ⌘⌥M
public struct DataInspectorPanel: DevToolPanel    // configurable ID
```

## MetricsProvider (for PerformancePanel)

```swift
@MainActor
public protocol MetricsProvider: Sendable {
    func currentMetrics() async -> [MetricGroup]
}

public struct MetricGroup: Sendable { public let name: String; public let metrics: [Metric] }
public struct Metric: Sendable { public let name: String; public let value: Double; public let unit: String; public let color: MetricColor }
public enum MetricColor: String, Sendable { case blue, purple, orange, red, green, gray }
```

## Window & Menu Types

```swift
@MainActor public final class DevToolsWindowManager    // open/close/isOpen standalone windows (macOS only; stubs on other platforms)
@MainActor public final class DevToolsTabbedWindow      // open/close shared tabbed window (macOS only; stubs on other platforms)
public struct DevToolsCommands: Commands                 // auto-generated Developer menu (macOS only)
```

### Platform Availability

- **Windowed** and **separateWindows** display modes are macOS-only. On iOS/tvOS/visionOS/watchOS, `openPanel()` always uses docked mode.
- `popOutPanel()` and `closePopOut()` are no-ops on non-macOS platforms.
- `DevToolsCommands` is only available on macOS (no menu bar on other platforms).
- `DiagnosticExporter.export()` (NSSavePanel) is macOS-only; use `exportData()` on other platforms.

## View Modifiers

```swift
extension View {
    public func devToolsDock(_ manager: DevToolsManager) -> some View
    public func environment(_ manager: DevToolsManager) -> some View
}
```
