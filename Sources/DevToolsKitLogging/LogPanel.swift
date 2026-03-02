import DevToolsKit
import SwiftUI

/// Built-in log viewer panel that displays entries from a ``DevToolsLogStore``.
///
/// Opens with shortcut ⌘⌥L. Register with a shared log store instance:
///
/// ```swift
/// let logStore = DevToolsLogStore()
/// manager.register(LogPanel(logStore: logStore))
/// ```
public struct LogPanel: DevToolPanel {
    public let id = "devtools.log"
    public let title = "Log Viewer"
    public let icon = "doc.text.magnifyingglass"
    public let keyboardShortcut = DevToolsKeyboardShortcut(key: "l")
    public let preferredSize = CGSize(width: 800, height: 600)
    public let minimumSize = CGSize(width: 600, height: 400)

    private let logStore: DevToolsLogStore
    private let keyPrefix: String

    /// - Parameters:
    ///   - logStore: The shared log store to display entries from.
    ///   - keyPrefix: UserDefaults key prefix for persisting column widths; defaults to `"devtools"`.
    public init(logStore: DevToolsLogStore, keyPrefix: String = "devtools") {
        self.logStore = logStore
        self.keyPrefix = keyPrefix
    }

    public func makeBody() -> AnyView {
        AnyView(LogPanelView(logStore: logStore, keyPrefix: keyPrefix))
    }
}
