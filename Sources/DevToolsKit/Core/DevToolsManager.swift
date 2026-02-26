import Foundation
import Observation
import SwiftUI

/// Central registry and state manager for developer tools.
///
/// Create an instance with a key prefix to namespace UserDefaults keys,
/// then register panels and inject via the environment.
///
/// ```swift
/// @State private var devTools = DevToolsManager(keyPrefix: "myapp")
/// ```
@MainActor
@Observable
public final class DevToolsManager: Sendable {
    // MARK: - Configuration

    /// Prefix for all UserDefaults keys to prevent collisions.
    public let keyPrefix: String

    // MARK: - Registered Panels

    /// All registered panels in registration order.
    public private(set) var panels: [any DevToolPanel] = []

    // MARK: - Developer Mode Toggle

    /// Whether developer mode is enabled.
    public var isDeveloperMode: Bool {
        get {
            access(keyPath: \.isDeveloperMode)
            return UserDefaults.standard.bool(forKey: key("developerMode"))
        }
        set {
            withMutation(keyPath: \.isDeveloperMode) {
                UserDefaults.standard.set(newValue, forKey: key("developerMode"))
            }
        }
    }

    // MARK: - Log Level

    /// Current log level filter.
    public var logLevel: DevToolsLogLevel {
        get {
            access(keyPath: \.logLevel)
            let raw = UserDefaults.standard.string(forKey: key("logLevel")) ?? "info"
            return DevToolsLogLevel(rawValue: raw) ?? .info
        }
        set {
            withMutation(keyPath: \.logLevel) {
                UserDefaults.standard.set(newValue.rawValue, forKey: key("logLevel"))
            }
        }
    }

    // MARK: - Panel Display Modes

    /// Display mode per panel (persisted).
    public private(set) var panelDisplayModes: [String: PanelDisplayMode] = [:]

    /// Set the display mode for a panel.
    public func setDisplayMode(_ mode: PanelDisplayMode, for panelID: String) {
        panelDisplayModes[panelID] = mode
        UserDefaults.standard.set(mode.rawValue, forKey: key("panelMode.\(panelID)"))
    }

    /// Get the display mode for a panel.
    public func displayMode(for panelID: String) -> PanelDisplayMode {
        if let mode = panelDisplayModes[panelID] {
            return mode
        }
        if let raw = UserDefaults.standard.string(forKey: key("panelMode.\(panelID)")),
           let mode = PanelDisplayMode(rawValue: raw) {
            panelDisplayModes[panelID] = mode
            return mode
        }
        return .standalone
    }

    // MARK: - Dock State

    /// Current dock position.
    public var dockPosition: DockPosition {
        get {
            access(keyPath: \.dockPosition)
            let raw = UserDefaults.standard.string(forKey: key("dockPosition")) ?? "bottom"
            return DockPosition(rawValue: raw) ?? .bottom
        }
        set {
            withMutation(keyPath: \.dockPosition) {
                UserDefaults.standard.set(newValue.rawValue, forKey: key("dockPosition"))
            }
        }
    }

    /// Whether the dock is visible.
    public var isDockVisible: Bool {
        get {
            access(keyPath: \.isDockVisible)
            return UserDefaults.standard.bool(forKey: key("dockVisible"))
        }
        set {
            withMutation(keyPath: \.isDockVisible) {
                UserDefaults.standard.set(newValue, forKey: key("dockVisible"))
            }
        }
    }

    /// Persisted dock size (width for left/right, height for bottom).
    public var dockSize: CGFloat {
        get {
            access(keyPath: \.dockSize)
            let stored = UserDefaults.standard.double(forKey: key("dockSize"))
            return stored > 0 ? stored : 300
        }
        set {
            withMutation(keyPath: \.dockSize) {
                UserDefaults.standard.set(newValue, forKey: key("dockSize"))
            }
        }
    }

    /// Active panel ID in the dock.
    public var activeDockPanelID: String? {
        get {
            access(keyPath: \.activeDockPanelID)
            return UserDefaults.standard.string(forKey: key("activeDockPanel"))
        }
        set {
            withMutation(keyPath: \.activeDockPanelID) {
                UserDefaults.standard.set(newValue, forKey: key("activeDockPanel"))
            }
        }
    }

    // MARK: - Tabbed Window State

    /// Active panel ID in the tabbed window.
    public var activeTabbedPanelID: String?

    /// Whether the tabbed window is open.
    public var isTabbedWindowOpen: Bool = false

    // MARK: - Open Standalone Windows

    /// Set of currently open standalone panel IDs.
    public var openStandalonePanelIDs: Set<String> = []

    // MARK: - Diagnostic Providers

    /// Registered diagnostic providers.
    public private(set) var diagnosticProviders: [any DiagnosticProvider] = []

    // MARK: - Init

    public init(keyPrefix: String) {
        self.keyPrefix = keyPrefix
        loadPersistedPanelModes()
    }

    // MARK: - Panel Registration

    /// Register a panel with the manager.
    public func register(_ panel: any DevToolPanel) {
        guard !panels.contains(where: { $0.id == panel.id }) else { return }
        panels.append(panel)
    }

    /// Unregister a panel by ID.
    public func unregister(panelID: String) {
        panels.removeAll { $0.id == panelID }
        panelDisplayModes.removeValue(forKey: panelID)
    }

    /// Find a registered panel by ID.
    public func panel(for id: String) -> (any DevToolPanel)? {
        panels.first { $0.id == id }
    }

    // MARK: - Diagnostic Provider Registration

    /// Register a diagnostic provider.
    public func registerDiagnosticProvider(_ provider: any DiagnosticProvider) {
        diagnosticProviders.append(provider)
    }

    // MARK: - Panel Actions

    /// Open a panel in its current display mode.
    public func openPanel(_ panelID: String) {
        let mode = displayMode(for: panelID)
        switch mode {
        case .standalone:
            openStandalonePanelIDs.insert(panelID)
        case .tabbed:
            activeTabbedPanelID = panelID
            isTabbedWindowOpen = true
        case .docked:
            activeDockPanelID = panelID
            isDockVisible = true
        }
    }

    /// Close a panel.
    public func closePanel(_ panelID: String) {
        openStandalonePanelIDs.remove(panelID)
        if activeTabbedPanelID == panelID {
            activeTabbedPanelID = nil
        }
        if activeDockPanelID == panelID {
            activeDockPanelID = nil
        }
    }

    /// Move a panel to a different display mode.
    public func movePanel(_ panelID: String, to mode: PanelDisplayMode) {
        closePanel(panelID)
        setDisplayMode(mode, for: panelID)
        openPanel(panelID)
    }

    // MARK: - Private

    private func key(_ suffix: String) -> String {
        "\(keyPrefix).\(suffix)"
    }

    private func loadPersistedPanelModes() {
        // Modes are loaded lazily in displayMode(for:)
    }
}

// MARK: - Environment Key

private struct DevToolsManagerKey: EnvironmentKey {
    static let defaultValue: DevToolsManager? = nil
}

extension EnvironmentValues {
    /// The DevToolsManager injected into the environment.
    public var devToolsManager: DevToolsManager? {
        get { self[DevToolsManagerKey.self] }
        set { self[DevToolsManagerKey.self] = newValue }
    }
}

extension View {
    /// Inject a DevToolsManager into the environment.
    public func environment(_ manager: DevToolsManager) -> some View {
        environment(\.devToolsManager, manager)
    }
}
