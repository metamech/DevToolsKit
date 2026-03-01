import DevToolsKit
import SwiftUI

/// Panel displaying GitHub API status including rate limit and cache stats.
///
/// Since 0.4.0
public struct GitHubStatusPanel: DevToolPanel {
    /// Panel identifier.
    public let id = "devtools.github"
    /// Panel title.
    public let title = "GitHub"
    /// SF Symbol icon.
    public let icon = "network"
    /// Keyboard shortcut.
    public let keyboardShortcut = DevToolsKeyboardShortcut(key: "g")
    /// Preferred window size.
    public let preferredSize = CGSize(width: 500, height: 400)
    /// Minimum window size.
    public let minimumSize = CGSize(width: 350, height: 250)

    /// The GitHub client to display status for.
    let client: GitHubClient

    /// Creates a GitHub status panel.
    /// - Parameter client: The GitHub client to display status for.
    public init(client: GitHubClient) {
        self.client = client
    }

    public func makeBody() -> AnyView {
        AnyView(GitHubStatusPanelView(client: client))
    }
}
