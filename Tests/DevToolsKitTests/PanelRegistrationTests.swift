import Testing
import SwiftUI
@testable import DevToolsKit

@Suite(.serialized)
@MainActor
struct PanelRegistrationTests {

    struct MockPanel: DevToolPanel {
        let id: String
        let title: String
        let icon: String
        let keyboardShortcut: DevToolsKeyboardShortcut?
        let preferredSize: CGSize
        let minimumSize: CGSize

        init(
            id: String,
            title: String,
            icon: String = "wrench",
            keyboardShortcut: DevToolsKeyboardShortcut? = nil,
            preferredSize: CGSize = CGSize(width: 600, height: 400),
            minimumSize: CGSize = CGSize(width: 300, height: 200)
        ) {
            self.id = id
            self.title = title
            self.icon = icon
            self.keyboardShortcut = keyboardShortcut
            self.preferredSize = preferredSize
            self.minimumSize = minimumSize
        }

        func makeBody() -> AnyView {
            AnyView(Text("Mock: \(id)"))
        }
    }

    @Test func registerBuiltInPanels() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")
        let logStore = DevToolsLogStore()

        manager.register(LogPanel(logStore: logStore))
        manager.register(EnvironmentPanel())

        #expect(manager.panels.count == 2)
        #expect(manager.panel(for: "devtools.log") != nil)
        #expect(manager.panel(for: "devtools.environment") != nil)
    }

    @Test func registerCustomPanel() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")

        let custom = MockPanel(
            id: "my-app.debug",
            title: "My Debug Panel",
            keyboardShortcut: DevToolsKeyboardShortcut(key: "d")
        )

        manager.register(custom)
        #expect(manager.panels.count == 1)
        #expect(manager.panel(for: "my-app.debug")?.title == "My Debug Panel")
    }

    @Test func panelOrderPreserved() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")

        manager.register(MockPanel(id: "a", title: "A"))
        manager.register(MockPanel(id: "b", title: "B"))
        manager.register(MockPanel(id: "c", title: "C"))

        #expect(manager.panels.map(\.id) == ["a", "b", "c"])
    }

    @Test func logLevelComparable() {
        #expect(DevToolsLogLevel.debug < DevToolsLogLevel.info)
        #expect(DevToolsLogLevel.info < DevToolsLogLevel.warning)
        #expect(DevToolsLogLevel.warning < DevToolsLogLevel.error)
        #expect(!(DevToolsLogLevel.error < DevToolsLogLevel.debug))
    }

    @Test func keyPrefixIsolation() {
        let manager1 = DevToolsManager(keyPrefix: "app1.\(UUID().uuidString)")
        let manager2 = DevToolsManager(keyPrefix: "app2.\(UUID().uuidString)")

        manager1.isDeveloperMode = true
        manager2.isDeveloperMode = false

        #expect(manager1.isDeveloperMode == true)
        #expect(manager2.isDeveloperMode == false)
    }
}
