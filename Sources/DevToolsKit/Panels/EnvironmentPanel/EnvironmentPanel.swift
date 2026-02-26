import SwiftUI

/// Built-in panel that displays system and app environment information.
///
/// Shows macOS version, hardware model, memory, processor count, thermal state,
/// app version, and more. Opens with shortcut ⌘⌥E. Requires no configuration.
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
