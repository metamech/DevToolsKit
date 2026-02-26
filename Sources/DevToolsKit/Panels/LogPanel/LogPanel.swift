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

    /// - Parameter logStore: The shared log store to display entries from.
    public init(logStore: DevToolsLogStore) {
        self.logStore = logStore
    }

    public func makeBody() -> AnyView {
        AnyView(LogPanelView(logStore: logStore))
    }
}
