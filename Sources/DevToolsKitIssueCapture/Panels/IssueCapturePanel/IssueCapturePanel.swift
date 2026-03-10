import DevToolsKit
import SwiftUI

/// Built-in panel for viewing and managing issue captures.
///
/// Displays a filterable list of captured issues with detail view
/// and pattern analysis. Opens with shortcut ⌘⌥R.
///
/// ```swift
/// let store = IssueCaptureStore(storageDirectory: capturesURL)
/// manager.register(IssueCapturePanel(store: store, providers: [myProvider]))
/// ```
///
/// Since 0.5.0
public struct IssueCapturePanel: DevToolPanel {
    public let id = "devtools.issueCapture"
    public let title = "Issue Capture"
    public let icon = "camera.viewfinder"
    public let keyboardShortcut = DevToolsKeyboardShortcut(key: "r")
    public let preferredSize = CGSize(width: 900, height: 600)
    public let minimumSize = CGSize(width: 600, height: 400)

    private let store: IssueCaptureStore
    private let providers: [any IssueCaptureProvider]

    /// - Parameters:
    ///   - store: The shared issue capture store.
    ///   - providers: The issue capture providers available for creating new captures.
    public init(store: IssueCaptureStore, providers: [any IssueCaptureProvider]) {
        self.store = store
        self.providers = providers
    }

    public func makeBody() -> AnyView {
        AnyView(IssueCapturePanelView(store: store, providers: providers))
    }
}
