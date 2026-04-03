import Testing
@testable import DevToolsKitPalette

@MainActor
@Suite("PaletteAction")
struct PaletteActionTests {

    @Test("init stores all properties")
    func initStoresProperties() {
        let action = PaletteAction(
            id: "test.action",
            title: "Test Action",
            subtitle: "A subtitle",
            category: .general,
            iconName: "star",
            keyboardShortcut: "⌘T",
            execute: { }
        )

        #expect(action.id == "test.action")
        #expect(action.title == "Test Action")
        #expect(action.subtitle == "A subtitle")
        #expect(action.category == .general)
        #expect(action.iconName == "star")
        #expect(action.keyboardShortcut == "⌘T")
        #expect(action.isEnabled())
        #expect(action.children == nil)
    }

    @Test("builder creates action with all fields")
    func builderCreatesAction() {
        let action = PaletteAction.build()
            .id("build.test")
            .titled("Built Action")
            .subtitle("Via builder")
            .category(.settings)
            .icon("gear")
            .keyed("⌘,")
            .execute { }
            .build()

        #expect(action.id == "build.test")
        #expect(action.title == "Built Action")
        #expect(action.subtitle == "Via builder")
        #expect(action.category == .settings)
        #expect(action.iconName == "gear")
        #expect(action.keyboardShortcut == "⌘,")
    }

    @Test("builder drillDown sets no-op execute")
    func builderDrillDown() {
        let child = PaletteAction(
            id: "child",
            title: "Child",
            category: .general,
            execute: { }
        )

        let parent = PaletteAction.build()
            .id("parent")
            .titled("Parent")
            .category(.general)
            .children([child])
            .drillDown()
            .build()

        #expect(parent.children?.count == 1)
        #expect(parent.children?.first?.id == "child")
    }

    @Test("toggle factory creates action with current state subtitle")
    func toggleFactory() {
        let on = PaletteAction.toggle(
            id: "toggle.test",
            title: "Dark Mode",
            current: true,
            action: { }
        )

        #expect(on.subtitle == "Currently: On")
        #expect(on.category == .settings)

        let off = PaletteAction.toggle(
            id: "toggle.test",
            title: "Dark Mode",
            current: false,
            action: { }
        )

        #expect(off.subtitle == "Currently: Off")
    }

    @Test("isEnabled closure is respected")
    func isEnabledClosure() {
        var enabled = false
        let action = PaletteAction(
            id: "gated",
            title: "Gated",
            category: .general,
            isEnabled: { enabled },
            execute: { }
        )

        #expect(!action.isEnabled())
        enabled = true
        #expect(action.isEnabled())
    }
}
