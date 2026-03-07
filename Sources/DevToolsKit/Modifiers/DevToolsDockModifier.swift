import SwiftUI

/// View modifier that wraps content in a split view with a dockable developer tools panel.
struct DevToolsDockModifier: ViewModifier {
    @Bindable var manager: DevToolsManager

    func body(content: Content) -> some View {
        Group {
            if manager.isDockVisible {
                splitView(content: content)
            } else {
                content
            }
        }
        .animation(.easeInOut(duration: 0.2), value: manager.isDockVisible)
        .animation(.easeInOut(duration: 0.2), value: manager.dockPosition)
    }

    @ViewBuilder
    private func splitView(content: Content) -> some View {
        #if os(macOS)
        switch manager.dockPosition {
        case .bottom:
            VSplitView {
                content
                DevToolsDockView(manager: manager)
                    .frame(minHeight: 150, idealHeight: manager.dockSize, maxHeight: 600)
            }
        case .right:
            HSplitView {
                content
                DevToolsDockView(manager: manager)
                    .frame(minWidth: 200, idealWidth: manager.dockSize, maxWidth: 800)
            }
        case .left:
            HSplitView {
                DevToolsDockView(manager: manager)
                    .frame(minWidth: 200, idealWidth: manager.dockSize, maxWidth: 800)
                content
            }
        }
        #else
        NavigationSplitView {
            panelSidebar
        } detail: {
            dockDetail(mainContent: content)
        }
        #endif
    }

    #if !os(macOS)
    private var panelSidebar: some View {
        List(manager.panels, id: \.id, selection: Binding(
            get: { manager.activeDockPanelID },
            set: { manager.activeDockPanelID = $0 }
        )) { panel in
            Label(panel.title, systemImage: panel.icon)
                .tag(panel.id)
        }
        .navigationTitle("Developer Tools")
    }

    @ViewBuilder
    private func dockDetail(mainContent: Content) -> some View {
        if let activeID = manager.activeDockPanelID,
            let panel = manager.panel(for: activeID)
        {
            panel.makeBody()
        } else {
            mainContent
        }
    }
    #endif
}

extension View {
    /// Attach a dockable developer tools panel to this view.
    ///
    /// ```swift
    /// ContentView()
    ///     .devToolsDock(devToolsManager)
    /// ```
    public func devToolsDock(_ manager: DevToolsManager) -> some View {
        modifier(DevToolsDockModifier(manager: manager))
    }
}
