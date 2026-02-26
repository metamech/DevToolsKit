import SwiftUI

/// Built-in data inspector panel for viewing JSON/key-value data.
public struct DataInspectorPanel: DevToolPanel {
    public let id: String
    public let title: String
    public let icon = "eye.circle"
    public let keyboardShortcut: DevToolsKeyboardShortcut?
    public let preferredSize = CGSize(width: 600, height: 500)
    public let minimumSize = CGSize(width: 400, height: 300)

    private let data: Any
    private let dataTitle: String

    public init(
        id: String = "devtools.data-inspector",
        title: String = "Data Inspector",
        dataTitle: String = "Data",
        data: Any,
        keyboardShortcut: DevToolsKeyboardShortcut? = nil
    ) {
        self.id = id
        self.title = title
        self.dataTitle = dataTitle
        self.data = data
        self.keyboardShortcut = keyboardShortcut
    }

    public func makeBody() -> AnyView {
        AnyView(DataInspectorView(title: dataTitle, json: data))
    }
}
