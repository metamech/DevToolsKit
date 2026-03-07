#if os(macOS)
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
    private let onExportDiagnostics: (() -> Void)?

    /// - Parameters:
    ///   - manager: The shared DevToolsManager.
    ///   - onExportDiagnostics: Optional custom export handler; if `nil`, the built-in exporter is used.
    public init(
        manager: DevToolsManager,
        onExportDiagnostics: (() -> Void)? = nil
    ) {
        self.manager = manager
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

            Picker("Display Mode", selection: Bindable(manager).displayMode) {
                Text("Docked").tag(DevToolsDisplayMode.docked)
                Text("Windowed").tag(DevToolsDisplayMode.windowed)
                Text("Separate Windows").tag(DevToolsDisplayMode.separateWindows)
            }

            Button("Show All") {
                for panel in manager.panels {
                    manager.openPanel(panel.id)
                }
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
        manager.openPanel(panel.id)
    }
}
#endif
