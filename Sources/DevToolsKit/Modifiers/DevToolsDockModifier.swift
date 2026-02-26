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
    }
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
