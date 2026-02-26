import SwiftUI

/// Built-in log viewer panel.
public struct LogPanel: DevToolPanel {
    public let id = "devtools.log"
    public let title = "Log Viewer"
    public let icon = "doc.text.magnifyingglass"
    public let keyboardShortcut = DevToolsKeyboardShortcut(key: "l")
    public let preferredSize = CGSize(width: 800, height: 600)
    public let minimumSize = CGSize(width: 600, height: 400)

    private let logStore: DevToolsLogStore

    public init(logStore: DevToolsLogStore) {
        self.logStore = logStore
    }

    public func makeBody() -> AnyView {
        AnyView(LogPanelView(logStore: logStore))
    }
}
