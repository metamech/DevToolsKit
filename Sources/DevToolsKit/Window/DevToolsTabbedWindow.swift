#if canImport(AppKit)
import AppKit
import SwiftUI

/// Manages a single tabbed window that shows multiple panels with a tab bar.
@MainActor
public final class DevToolsTabbedWindow {
    private var window: NSWindow?
    private weak var manager: DevToolsManager?

    public init() {}

    /// Open (or bring to front) the shared tabbed window.
    ///
    /// - Parameter manager: The shared DevToolsManager that owns the panel registry.
    public func open(manager: DevToolsManager) {
        self.manager = manager

        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = DevToolsTabbedContentView(manager: manager)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: CGSize(width: 800, height: 600)),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Developer Tools"
        window.contentView = NSHostingView(rootView: contentView)
        window.contentMinSize = CGSize(width: 500, height: 400)
        window.center()
        window.setFrameAutosaveName("DevTools.TabbedWindow")
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    /// Close the tabbed window.
    public func close() {
        window?.close()
        window = nil
        manager?.isTabbedWindowOpen = false
    }

    /// Whether the tabbed window is currently visible.
    public var isOpen: Bool {
        window?.isVisible ?? false
    }
}
#else
import SwiftUI

/// Stub tabbed window for non-macOS platforms where NSWindow is unavailable.
@MainActor
public final class DevToolsTabbedWindow {
    public init() {}

    /// No-op on non-macOS platforms.
    public func open(manager: DevToolsManager) {}

    /// No-op on non-macOS platforms.
    public func close() {}

    /// Always returns `false` on non-macOS platforms.
    public var isOpen: Bool { false }
}
#endif

// MARK: - Tabbed Content View

struct DevToolsTabbedContentView: View {
    @Bindable var manager: DevToolsManager

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            panelContent
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(manager.panels, id: \.id) { panel in
                    tabButton(for: panel)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 6)
        .background(.bar)
    }

    private func tabButton(for panel: any DevToolPanel) -> some View {
        Button {
            manager.activeTabbedPanelID = panel.id
        } label: {
            HStack(spacing: 6) {
                Image(systemName: panel.icon)
                    .font(.caption)
                Text(panel.title)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                manager.activeTabbedPanelID == panel.id
                    ? Color.accentColor.opacity(0.15)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .contextMenu {
            Button("Pop Out to Window") {
                manager.popOutPanel(panel.id)
            }
            Divider()
            Button("Close") {
                manager.closePanel(panel.id)
            }
        }
        #endif
    }

    @ViewBuilder
    private var panelContent: some View {
        if let activeID = manager.activeTabbedPanelID,
            let panel = manager.panel(for: activeID)
        {
            panel.makeBody()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let firstPanel = manager.panels.first {
            firstPanel.makeBody()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    manager.activeTabbedPanelID = firstPanel.id
                }
        } else {
            ContentUnavailableView(
                "No Panels",
                systemImage: "rectangle.3.group",
                description: Text("Register panels to see them here.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
