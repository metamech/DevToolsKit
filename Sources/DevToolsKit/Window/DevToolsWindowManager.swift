import SwiftUI
import AppKit

/// Manages standalone NSWindows for developer tool panels.
///
/// Each panel gets its own window with frame autosave. Windows are kept
/// separate from the standard Window menu.
@MainActor
public final class DevToolsWindowManager {
    private var windows: [String: NSWindow] = [:]

    public init() {}

    /// Open a panel as a standalone window, or bring it to front if already open.
    ///
    /// - Parameter panel: The panel to display.
    public func open(panel: any DevToolPanel) {
        if let existing = windows[panel.id], existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let window = createWindow(
            title: panel.title,
            view: panel.makeBody(),
            size: panel.preferredSize,
            minSize: panel.minimumSize,
            autosaveName: "DevTools.\(panel.id)"
        )
        windows[panel.id] = window
        window.makeKeyAndOrderFront(nil)
    }

    /// Close a panel's standalone window.
    public func close(panelID: String) {
        windows[panelID]?.close()
        windows.removeValue(forKey: panelID)
    }

    /// Check if a panel's window is currently visible.
    public func isOpen(panelID: String) -> Bool {
        windows[panelID]?.isVisible ?? false
    }

    /// Close all standalone windows.
    public func closeAll() {
        for (_, window) in windows {
            window.close()
        }
        windows.removeAll()
    }

    private func createWindow(
        title: String,
        view: some View,
        size: CGSize,
        minSize: CGSize,
        autosaveName: String
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = NSHostingView(rootView: view)
        window.contentMinSize = minSize
        window.center()
        window.setFrameAutosaveName(autosaveName)
        return window
    }
}
