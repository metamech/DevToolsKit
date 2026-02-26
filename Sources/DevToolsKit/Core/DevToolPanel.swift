import SwiftUI

/// Keyboard shortcut definition for a dev tool panel.
///
/// Used by ``DevToolPanel/keyboardShortcut`` to assign a global shortcut
/// that opens the panel from the Developer menu.
public struct DevToolsKeyboardShortcut: Sendable {
    /// The key character (e.g., `"l"` for ⌘⌥L).
    public let key: Character

    /// Modifier keys. Defaults to `[.command, .option]`.
    public let modifiers: EventModifiers

    /// - Parameters:
    ///   - key: The key character for the shortcut.
    ///   - modifiers: Modifier keys; defaults to Command+Option.
    public init(key: Character, modifiers: EventModifiers = [.command, .option]) {
        self.key = key
        self.modifiers = modifiers
    }
}

/// Protocol defining a developer tool panel.
///
/// Conform to this protocol to create custom panels that integrate with
/// DevToolsKit's window management, tabbed view, and dock system.
///
/// ```swift
/// struct MyCustomPanel: DevToolPanel {
///     let id = "my-custom"
///     let title = "My Panel"
///     let icon = "wrench"
///     let keyboardShortcut = DevToolsKeyboardShortcut(key: "k")
///     let preferredSize = CGSize(width: 600, height: 400)
///     let minimumSize = CGSize(width: 400, height: 300)
///
///     func makeBody() -> AnyView {
///         AnyView(Text("Hello from my panel"))
///     }
/// }
/// ```
@MainActor
public protocol DevToolPanel: Identifiable, Sendable where ID == String {
    /// Stable identifier used for persistence and panel tracking.
    var id: String { get }

    /// Display title shown in tabs, window titles, and menus.
    var title: String { get }

    /// SF Symbol name for the panel icon.
    var icon: String { get }

    /// Optional keyboard shortcut for opening this panel.
    var keyboardShortcut: DevToolsKeyboardShortcut? { get }

    /// Default window size when opened standalone.
    var preferredSize: CGSize { get }

    /// Minimum window size constraint.
    var minimumSize: CGSize { get }

    /// Create the panel's view content.
    func makeBody() -> AnyView
}

// MARK: - Defaults

extension DevToolPanel {
    public var keyboardShortcut: DevToolsKeyboardShortcut? { nil }
    public var preferredSize: CGSize { CGSize(width: 700, height: 500) }
    public var minimumSize: CGSize { CGSize(width: 400, height: 300) }
}
