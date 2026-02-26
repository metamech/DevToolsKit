import SwiftUI

/// SwiftUI Commands that add a "Developer" menu with all registered panels.
///
/// ```swift
/// .commands {
///     if devTools.isDeveloperMode {
///         DevToolsCommands(manager: devTools)
///     }
/// }
/// ```
public struct DevToolsCommands: Commands {
    private let manager: DevToolsManager
    private let windowManager: DevToolsWindowManager
    private let tabbedWindow: DevToolsTabbedWindow
    private let onExportDiagnostics: (() -> Void)?

    /// - Parameters:
    ///   - manager: The shared DevToolsManager.
    ///   - windowManager: Manager for standalone panel windows; a default is created if omitted.
    ///   - tabbedWindow: Manager for the shared tabbed window; a default is created if omitted.
    ///   - onExportDiagnostics: Optional custom export handler; if `nil`, the built-in exporter is used.
    public init(
        manager: DevToolsManager,
        windowManager: DevToolsWindowManager = DevToolsWindowManager(),
        tabbedWindow: DevToolsTabbedWindow = DevToolsTabbedWindow(),
        onExportDiagnostics: (() -> Void)? = nil
    ) {
        self.manager = manager
        self.windowManager = windowManager
        self.tabbedWindow = tabbedWindow
        self.onExportDiagnostics = onExportDiagnostics
    }

    public var body: some Commands {
        CommandMenu("Developer") {
            ForEach(manager.panels, id: \.id) { panel in
                panelButton(for: panel)
            }

            if !manager.panels.isEmpty {
                Divider()
            }

            Button("Show All (Tabbed)") {
                for panel in manager.panels {
                    manager.setDisplayMode(.tabbed, for: panel.id)
                }
                tabbedWindow.open(manager: manager)
            }
            .keyboardShortcut("d", modifiers: [.command, .option, .shift])

            Divider()

            Button("Export Diagnostics...") {
                if let handler = onExportDiagnostics {
                    handler()
                } else {
                    Task { @MainActor in
                        let exporter = DiagnosticExporter(manager: manager)
                        await exporter.export()
                    }
                }
            }

            Divider()

            Picker("Log Level", selection: Bindable(manager).logLevel) {
                ForEach(DevToolsLogLevel.allCases, id: \.self) { level in
                    Text(level.displayName).tag(level)
                }
            }

            Divider()

            Toggle("Developer Mode", isOn: Bindable(manager).isDeveloperMode)
        }
    }

    @ViewBuilder
    private func panelButton(for panel: any DevToolPanel) -> some View {
        if let shortcut = panel.keyboardShortcut {
            Button(panel.title) {
                openPanel(panel)
            }
            .keyboardShortcut(KeyEquivalent(shortcut.key), modifiers: shortcut.modifiers)
        } else {
            Button(panel.title) {
                openPanel(panel)
            }
        }
    }

    private func openPanel(_ panel: any DevToolPanel) {
        let mode = manager.displayMode(for: panel.id)
        switch mode {
        case .standalone:
            windowManager.open(panel: panel)
            manager.openStandalonePanelIDs.insert(panel.id)
        case .tabbed:
            manager.activeTabbedPanelID = panel.id
            tabbedWindow.open(manager: manager)
        case .docked:
            manager.activeDockPanelID = panel.id
            manager.isDockVisible = true
        }
    }
}
