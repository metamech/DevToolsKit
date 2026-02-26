import SwiftUI

/// Built-in environment information panel.
public struct EnvironmentPanel: DevToolPanel {
    public let id = "devtools.environment"
    public let title = "Environment"
    public let icon = "gearshape.2"
    public let keyboardShortcut = DevToolsKeyboardShortcut(key: "e")
    public let preferredSize = CGSize(width: 500, height: 400)
    public let minimumSize = CGSize(width: 350, height: 300)

    public init() {}

    public func makeBody() -> AnyView {
        AnyView(EnvironmentPanelView())
    }
}
