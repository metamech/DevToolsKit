import SwiftUI

/// Dockable panel container with tab bar, panel content, and toolbar.
struct DevToolsDockView: View {
    @Bindable var manager: DevToolsManager

    var body: some View {
        VStack(spacing: 0) {
            dockToolbar
            Divider()
            tabBar
            Divider()
            panelContent
        }
    }

    private var dockToolbar: some View {
        HStack(spacing: 8) {
            Text("Developer Tools")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            // Position picker
            Picker("Position", selection: $manager.dockPosition) {
                ForEach(DockPosition.allCases, id: \.self) { position in
                    Image(systemName: positionIcon(position))
                        .tag(position)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 100)

            Button {
                if let panelID = manager.activeDockPanelID {
                    manager.popOutPanel(panelID)
                }
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
            }
            .help("Pop out to window")
            .disabled(manager.activeDockPanelID == nil)

            Button {
                manager.isDockVisible = false
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .help("Close dock")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(manager.panels, id: \.id) { panel in
                    Button {
                        manager.activeDockPanelID = panel.id
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: panel.icon)
                                .font(.caption2)
                            Text(panel.title)
                                .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            manager.activeDockPanelID == panel.id
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Pop Out to Window") {
                            manager.popOutPanel(panel.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var panelContent: some View {
        if let activeID = manager.activeDockPanelID,
            let panel = manager.panel(for: activeID)
        {
            panel.makeBody()
        } else if let firstPanel = manager.panels.first {
            firstPanel.makeBody()
                .onAppear {
                    manager.activeDockPanelID = firstPanel.id
                }
        } else {
            ContentUnavailableView(
                "No Docked Panels",
                systemImage: "rectangle.bottomhalf.inset.filled",
                description: Text("Register panels to see them here.")
            )
        }
    }

    private func positionIcon(_ position: DockPosition) -> String {
        switch position {
        case .bottom: "rectangle.bottomhalf.inset.filled"
        case .right: "rectangle.trailinghalf.inset.filled"
        case .left: "rectangle.leadinghalf.inset.filled"
        }
    }
}
