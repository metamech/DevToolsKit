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

    // MARK: - Panel Display Modes

    @Test func defaultDisplayModeIsStandalone() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")
        #expect(manager.displayMode(for: "any-panel") == .standalone)
    }

    @Test func setAndGetDisplayMode() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")

        manager.setDisplayMode(.tabbed, for: "panel-1")
        #expect(manager.displayMode(for: "panel-1") == .tabbed)

        manager.setDisplayMode(.docked, for: "panel-1")
        #expect(manager.displayMode(for: "panel-1") == .docked)
    }

    // MARK: - Panel Actions

    @Test func openStandalonePanel() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")
        manager.register(TestPanel(id: "test-1", title: "Test"))

        manager.openPanel("test-1")
        #expect(manager.openStandalonePanelIDs.contains("test-1"))
    }

    @Test func openTabbedPanel() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")
        manager.register(TestPanel(id: "test-1", title: "Test"))
        manager.setDisplayMode(.tabbed, for: "test-1")

        manager.openPanel("test-1")
        #expect(manager.activeTabbedPanelID == "test-1")
        #expect(manager.isTabbedWindowOpen == true)
    }

    @Test func openDockedPanel() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")
        manager.register(TestPanel(id: "test-1", title: "Test"))
        manager.setDisplayMode(.docked, for: "test-1")

        manager.openPanel("test-1")
        #expect(manager.activeDockPanelID == "test-1")
        #expect(manager.isDockVisible == true)
    }

    @Test func closePanel() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")
        manager.register(TestPanel(id: "test-1", title: "Test"))

        manager.openPanel("test-1")
        #expect(manager.openStandalonePanelIDs.contains("test-1"))

        manager.closePanel("test-1")
        #expect(!manager.openStandalonePanelIDs.contains("test-1"))
    }

    @Test func movePanelBetweenModes() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")
        manager.register(TestPanel(id: "test-1", title: "Test"))

        manager.openPanel("test-1")
        #expect(manager.openStandalonePanelIDs.contains("test-1"))

        manager.movePanel("test-1", to: .docked)
        #expect(!manager.openStandalonePanelIDs.contains("test-1"))
        #expect(manager.activeDockPanelID == "test-1")
        #expect(manager.displayMode(for: "test-1") == .docked)
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
