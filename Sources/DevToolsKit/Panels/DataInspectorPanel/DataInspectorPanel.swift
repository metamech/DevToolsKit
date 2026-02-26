import SwiftUI

/// Built-in panel for viewing JSON or key-value data as a collapsible tree.
///
/// Useful for inspecting configuration, API responses, or any structured data.
/// Multiple instances can coexist with different IDs.
public struct DataInspectorPanel: DevToolPanel {
    public let id: String
    public let title: String
    public let icon = "eye.circle"
    public let keyboardShortcut: DevToolsKeyboardShortcut?
    public let preferredSize = CGSize(width: 600, height: 500)
    public let minimumSize = CGSize(width: 400, height: 300)

    private let data: Any
    private let dataTitle: String

    /// - Parameters:
    ///   - id: Stable panel identifier; defaults to `"devtools.data-inspector"`.
    ///   - title: Menu/tab title; defaults to `"Data Inspector"`.
    ///   - dataTitle: Heading shown inside the inspector view.
    ///   - data: The data to inspect (dictionary, array, or JSON-compatible value).
    ///   - keyboardShortcut: Optional keyboard shortcut.
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
