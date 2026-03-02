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

    // MARK: - Internal Window Manager

    /// Shared window manager for standalone / pop-out windows.
    internal let windowManager = DevToolsWindowManager()

    /// Shared tabbed window for windowed display mode.
    internal let tabbedWindow = DevToolsTabbedWindow()

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

    // MARK: - Global Display Mode

    /// How all panels are displayed: docked, windowed (tabbed), or separate windows.
    ///
    /// Changing the display mode takes effect the next time a panel is opened.
    /// Persisted to UserDefaults under `{keyPrefix}.displayMode`.
    ///
    /// Since 0.4.0
    public var displayMode: DevToolsDisplayMode {
        get {
            access(keyPath: \.displayMode)
            let raw = UserDefaults.standard.string(forKey: key("displayMode")) ?? "windowed"
            return DevToolsDisplayMode(rawValue: raw) ?? .windowed
        }
        set {
            withMutation(keyPath: \.displayMode) {
                UserDefaults.standard.set(newValue.rawValue, forKey: key("displayMode"))
            }
        }
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

    /// Set of currently open standalone panel IDs (pop-outs or separate-window mode).
    public var openStandalonePanelIDs: Set<String> = []

    // MARK: - Diagnostic Providers

    /// Registered diagnostic providers.
    public private(set) var diagnosticProviders: [any DiagnosticProvider] = []

    // MARK: - Init

    /// Create a manager with a UserDefaults key prefix for state isolation.
    ///
    /// - Parameter keyPrefix: Prefix for all persisted keys (e.g., `"myapp"`).
    public init(keyPrefix: String) {
        self.keyPrefix = keyPrefix
        migratePerPanelModesToGlobalIfNeeded()
    }

    // MARK: - Panel Registration

    /// Register a panel. Duplicate IDs are silently ignored.
    ///
    /// - Parameter panel: The panel to register.
    public func register(_ panel: any DevToolPanel) {
        guard !panels.contains(where: { $0.id == panel.id }) else { return }
        panels.append(panel)
    }

    /// Remove a panel by its ID.
    ///
    /// - Parameter panelID: The panel's stable identifier.
    public func unregister(panelID: String) {
        panels.removeAll { $0.id == panelID }
    }

    /// Look up a registered panel by its stable identifier.
    ///
    /// - Parameter id: The panel ID to search for.
    /// - Returns: The panel, or `nil` if not registered.
    public func panel(for id: String) -> (any DevToolPanel)? {
        panels.first { $0.id == id }
    }

    // MARK: - Diagnostic Provider Registration

    /// Register a diagnostic provider for export.
    ///
    /// - Parameter provider: The provider whose `collect()` will be called during export.
    public func registerDiagnosticProvider(_ provider: any DiagnosticProvider) {
        diagnosticProviders.append(provider)
    }

    // MARK: - Panel Actions

    /// Open a panel according to the current global display mode.
    ///
    /// - Parameter panelID: The panel's stable identifier.
    public func openPanel(_ panelID: String) {
        switch displayMode {
        case .docked:
            activeDockPanelID = panelID
            isDockVisible = true
        case .windowed:
            activeTabbedPanelID = panelID
            isTabbedWindowOpen = true
            tabbedWindow.open(manager: self)
        case .separateWindows:
            if let panel = panel(for: panelID) {
                windowManager.open(panel: panel)
            }
            openStandalonePanelIDs.insert(panelID)
        }
    }

    /// Close a panel across all display modes.
    ///
    /// - Parameter panelID: The panel's stable identifier.
    public func closePanel(_ panelID: String) {
        openStandalonePanelIDs.remove(panelID)
        windowManager.close(panelID: panelID)
        if activeTabbedPanelID == panelID {
            activeTabbedPanelID = nil
        }
        if activeDockPanelID == panelID {
            activeDockPanelID = nil
        }
    }

    /// Open a panel in its own standalone window without changing the global display mode.
    ///
    /// Use this to "pop out" a panel from the dock or tabbed window into a floating window.
    ///
    /// - Parameter panelID: The panel's stable identifier.
    ///
    /// Since 0.4.0
    public func popOutPanel(_ panelID: String) {
        guard let panel = panel(for: panelID) else { return }
        openStandalonePanelIDs.insert(panelID)
        windowManager.open(panel: panel)
    }

    /// Close a popped-out standalone window.
    ///
    /// - Parameter panelID: The panel's stable identifier.
    ///
    /// Since 0.4.0
    public func closePopOut(_ panelID: String) {
        openStandalonePanelIDs.remove(panelID)
        windowManager.close(panelID: panelID)
    }

    // MARK: - Private

    func key(_ suffix: String) -> String {
        "\(keyPrefix).\(suffix)"
    }

    /// Migrate legacy per-panel display modes to the new global display mode.
    ///
    /// Scans for `{prefix}.panelMode.*` keys, determines the dominant mode,
    /// and maps it to the corresponding global `DevToolsDisplayMode`. Cleans up
    /// the old keys after migration.
    private func migratePerPanelModesToGlobalIfNeeded() {
        let defaults = UserDefaults.standard
        let prefix = key("panelMode.")

        // Only migrate if we haven't already set a global display mode
        guard defaults.string(forKey: key("displayMode")) == nil else { return }

        // Collect all persisted per-panel modes
        let allKeys = defaults.dictionaryRepresentation().keys
        let panelModeKeys = allKeys.filter { $0.hasPrefix(prefix) }

        guard !panelModeKeys.isEmpty else { return }

        var counts: [String: Int] = [:]
        for modeKey in panelModeKeys {
            if let raw = defaults.string(forKey: modeKey) {
                counts[raw, default: 0] += 1
            }
        }

        // Map dominant per-panel mode to global mode
        let dominant = counts.max(by: { $0.value < $1.value })?.key ?? "standalone"
        let globalMode: DevToolsDisplayMode
        switch dominant {
        case "tabbed": globalMode = .windowed
        case "docked": globalMode = .docked
        default: globalMode = .separateWindows
        }

        defaults.set(globalMode.rawValue, forKey: key("displayMode"))

        // Clean up legacy keys
        for modeKey in panelModeKeys {
            defaults.removeObject(forKey: modeKey)
        }
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
