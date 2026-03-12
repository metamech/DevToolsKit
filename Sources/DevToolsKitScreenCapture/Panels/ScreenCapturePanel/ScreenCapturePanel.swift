import DevToolsKit
import SwiftUI

/// Built-in panel for browsing and managing screen capture history.
///
/// Displays a filterable grid of capture thumbnails with detail view
/// and quick export actions. Opens with shortcut ⌘⌥H.
///
/// ```swift
/// let store = ScreenCaptureStore(storageDirectory: capturesURL)
/// manager.register(ScreenCapturePanel(store: store))
/// ```
///
/// Since 0.5.0
public struct ScreenCapturePanel: DevToolPanel {
    public let id = "devtools.screenCapture"
    public let title = "Screen Captures"
    public let icon = "photo.on.rectangle"
    public let keyboardShortcut = DevToolsKeyboardShortcut(key: "h")
    public let preferredSize = CGSize(width: 800, height: 600)
    public let minimumSize = CGSize(width: 500, height: 400)

    private let store: ScreenCaptureStore

    /// - Parameter store: The shared screen capture store.
    public init(store: ScreenCaptureStore) {
        self.store = store
    }

    public func makeBody() -> AnyView {
        AnyView(ScreenCapturePanelView(store: store))
    }
}
