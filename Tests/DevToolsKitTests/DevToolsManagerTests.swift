import SwiftUI
import Testing

@testable import DevToolsKit

@Suite(.serialized)
@MainActor
struct DevToolsManagerTests {
    // MARK: - Test Panel

    struct TestPanel: DevToolPanel {
        let id: String
        let title: String
        let icon = "wrench"
        let keyboardShortcut: DevToolsKeyboardShortcut? = nil
        let preferredSize = CGSize(width: 400, height: 300)
        let minimumSize = CGSize(width: 200, height: 150)

        func makeBody() -> AnyView {
            AnyView(Text("Test Panel: \(id)"))
        }
    }

    // MARK: - Registration

    @Test func registerPanel() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")
        let panel = TestPanel(id: "test-1", title: "Test 1")

        manager.register(panel)
        #expect(manager.panels.count == 1)
        #expect(manager.panels.first?.id == "test-1")
    }

    @Test func registerDuplicatePanelIgnored() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")
        let panel = TestPanel(id: "test-1", title: "Test 1")

        manager.register(panel)
        manager.register(panel)
        #expect(manager.panels.count == 1)
    }

    @Test func unregisterPanel() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")
        manager.register(TestPanel(id: "test-1", title: "Test 1"))
        manager.register(TestPanel(id: "test-2", title: "Test 2"))

        manager.unregister(panelID: "test-1")
        #expect(manager.panels.count == 1)
        #expect(manager.panels.first?.id == "test-2")
    }

    @Test func findPanelByID() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")
        manager.register(TestPanel(id: "test-1", title: "Test 1"))

        #expect(manager.panel(for: "test-1")?.title == "Test 1")
        #expect(manager.panel(for: "nonexistent") == nil)
    }

    // MARK: - Developer Mode

    @Test func developerModeToggle() {
        let prefix = "test.\(UUID().uuidString)"
        let manager = DevToolsManager(keyPrefix: prefix)

        manager.isDeveloperMode = true
        #expect(manager.isDeveloperMode == true)

        manager.isDeveloperMode = false
        #expect(manager.isDeveloperMode == false)
    }

    // MARK: - Log Level

    @Test func logLevelPersistence() {
        let prefix = "test.\(UUID().uuidString)"
        let manager = DevToolsManager(keyPrefix: prefix)

        manager.logLevel = .warning
        #expect(manager.logLevel == .warning)

        manager.logLevel = .debug
        #expect(manager.logLevel == .debug)
    }

    // MARK: - Global Display Mode

    @Test func globalDisplayModeDefaultsToWindowed() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")
        #expect(manager.displayMode == .windowed)
    }

    @Test func setGlobalDisplayMode_persists() {
        let prefix = "test.\(UUID().uuidString)"
        let manager = DevToolsManager(keyPrefix: prefix)

        manager.displayMode = .docked
        #expect(manager.displayMode == .docked)

        manager.displayMode = .separateWindows
        #expect(manager.displayMode == .separateWindows)

        // Verify persistence
        let raw = UserDefaults.standard.string(forKey: "\(prefix).displayMode")
        #expect(raw == "separateWindows")
    }

    @Test func openPanel_windowed_setsTabbedState() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")
        manager.register(TestPanel(id: "test-1", title: "Test"))
        manager.displayMode = .windowed

        manager.openPanel("test-1")
        #expect(manager.activeTabbedPanelID == "test-1")
        #expect(manager.isTabbedWindowOpen == true)
    }

    @Test func openPanel_docked_setsDockState() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")
        manager.register(TestPanel(id: "test-1", title: "Test"))
        manager.displayMode = .docked

        manager.openPanel("test-1")
        #expect(manager.activeDockPanelID == "test-1")
        #expect(manager.isDockVisible == true)
    }

    @Test func openPanel_separateWindows_insertsStandaloneID() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")
        manager.register(TestPanel(id: "test-1", title: "Test"))
        manager.displayMode = .separateWindows

        manager.openPanel("test-1")
        #expect(manager.openStandalonePanelIDs.contains("test-1"))
    }

    @Test func popOutPanel_insertsStandaloneID() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")
        manager.register(TestPanel(id: "test-1", title: "Test"))
        manager.displayMode = .windowed

        manager.popOutPanel("test-1")
        #expect(manager.openStandalonePanelIDs.contains("test-1"))
        // Global mode unchanged
        #expect(manager.displayMode == .windowed)
    }

    @Test func closePanel() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")
        manager.register(TestPanel(id: "test-1", title: "Test"))
        manager.displayMode = .separateWindows

        manager.openPanel("test-1")
        #expect(manager.openStandalonePanelIDs.contains("test-1"))

        manager.closePanel("test-1")
        #expect(!manager.openStandalonePanelIDs.contains("test-1"))
    }

    // MARK: - Migration

    @Test func migrationFromPerPanelTabbedToWindowed() {
        let prefix = "test.\(UUID().uuidString)"
        let defaults = UserDefaults.standard

        // Simulate legacy per-panel modes (mostly tabbed)
        defaults.set("tabbed", forKey: "\(prefix).panelMode.panel1")
        defaults.set("tabbed", forKey: "\(prefix).panelMode.panel2")
        defaults.set("standalone", forKey: "\(prefix).panelMode.panel3")

        let manager = DevToolsManager(keyPrefix: prefix)

        // Dominant mode was "tabbed" → should migrate to ".windowed"
        #expect(manager.displayMode == .windowed)

        // Legacy keys cleaned up
        #expect(defaults.string(forKey: "\(prefix).panelMode.panel1") == nil)
        #expect(defaults.string(forKey: "\(prefix).panelMode.panel2") == nil)
        #expect(defaults.string(forKey: "\(prefix).panelMode.panel3") == nil)
    }

    @Test func migrationFromPerPanelDockedToDocked() {
        let prefix = "test.\(UUID().uuidString)"
        let defaults = UserDefaults.standard

        defaults.set("docked", forKey: "\(prefix).panelMode.panel1")
        defaults.set("docked", forKey: "\(prefix).panelMode.panel2")

        let manager = DevToolsManager(keyPrefix: prefix)
        #expect(manager.displayMode == .docked)
    }

    @Test func migrationFallbackToSeparateWindows() {
        let prefix = "test.\(UUID().uuidString)"
        let defaults = UserDefaults.standard

        defaults.set("standalone", forKey: "\(prefix).panelMode.panel1")
        defaults.set("standalone", forKey: "\(prefix).panelMode.panel2")

        let manager = DevToolsManager(keyPrefix: prefix)
        #expect(manager.displayMode == .separateWindows)
    }

    // MARK: - Dock State

    @Test func dockPositionPersistence() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")

        manager.dockPosition = .right
        #expect(manager.dockPosition == .right)

        manager.dockPosition = .left
        #expect(manager.dockPosition == .left)
    }

    @Test func dockSizeDefault() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")
        #expect(manager.dockSize == 300)
    }

    // MARK: - Diagnostic Providers

    @Test func registerDiagnosticProvider() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")

        struct TestProvider: DiagnosticProvider {
            let sectionName = "test"
            func collect() async -> any Codable & Sendable { "test-data" }
        }

        manager.registerDiagnosticProvider(TestProvider())
        #expect(manager.diagnosticProviders.count == 1)
        #expect(manager.diagnosticProviders.first?.sectionName == "test")
    }
}
