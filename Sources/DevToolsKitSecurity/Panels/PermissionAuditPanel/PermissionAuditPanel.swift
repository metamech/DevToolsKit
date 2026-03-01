import DevToolsKit
import SwiftUI

/// Panel displaying the permission audit log with filtering.
///
/// Since 0.4.0
public struct PermissionAuditPanel: DevToolPanel {
    /// Panel identifier.
    public let id = "devtools.permissions"
    /// Panel title.
    public let title = "Permissions"
    /// SF Symbol icon.
    public let icon = "lock.shield"
    /// Keyboard shortcut.
    public let keyboardShortcut = DevToolsKeyboardShortcut(key: "p")
    /// Preferred window size.
    public let preferredSize = CGSize(width: 700, height: 500)
    /// Minimum window size.
    public let minimumSize = CGSize(width: 400, height: 300)

    /// The audit store to display.
    let store: PermissionAuditStore

    /// Creates a permission audit panel.
    /// - Parameter store: The audit store to display.
    public init(store: PermissionAuditStore) {
        self.store = store
    }

    public func makeBody() -> AnyView {
        AnyView(PermissionAuditPanelView(store: store))
    }
}
