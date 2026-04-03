import Foundation
import Testing
@testable import DevToolsKitPalette

@MainActor
@Suite("ActionRegistry")
struct ActionRegistryTests {

    private func makeRegistry() -> ActionRegistry {
        ActionRegistry(
            defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!,
            recentsKey: "test.recents"
        )
    }

    @Test("register and retrieve actions")
    func registerAndRetrieve() {
        let registry = makeRegistry()
        let action = PaletteAction(
            id: "test.1",
            title: "Alpha",
            category: .general,
            execute: { }
        )

        registry.register(action)
        let results = registry.allActions(filter: nil)
        #expect(results.count == 1)
        #expect(results.first?.id == "test.1")
    }

    @Test("register batch of actions")
    func registerBatch() {
        let registry = makeRegistry()
        let actions = [
            PaletteAction(id: "a", title: "A", category: .general, execute: { }),
            PaletteAction(id: "b", title: "B", category: .general, execute: { }),
        ]

        registry.register(actions)
        #expect(registry.allActions(filter: nil).count == 2)
    }

    @Test("unregister removes action")
    func unregister() {
        let registry = makeRegistry()
        registry.register(PaletteAction(id: "rm", title: "Remove Me", category: .general, execute: { }))
        #expect(registry.allActions(filter: nil).count == 1)

        registry.unregister(id: "rm")
        #expect(registry.allActions(filter: nil).isEmpty)
    }

    @Test("upsert by id")
    func upsertById() {
        let registry = makeRegistry()
        registry.register(PaletteAction(id: "up", title: "V1", category: .general, execute: { }))
        registry.register(PaletteAction(id: "up", title: "V2", category: .general, execute: { }))

        let results = registry.allActions(filter: nil)
        #expect(results.count == 1)
        #expect(results.first?.title == "V2")
    }

    @Test("filter returns fuzzy-matched results sorted by score")
    func filterFuzzyMatch() {
        let registry = makeRegistry()
        registry.register([
            PaletteAction(id: "a", title: "New Terminal", category: .general, execute: { }),
            PaletteAction(id: "b", title: "New File", category: .general, execute: { }),
            PaletteAction(id: "c", title: "Close All", category: .general, execute: { }),
        ])

        let results = registry.allActions(filter: "new")
        #expect(results.count == 2)
        // Both match "new" — "New Terminal" and "New File"
        let ids = results.map(\.id)
        #expect(ids.contains("a"))
        #expect(ids.contains("b"))
    }

    @Test("disabled actions are excluded")
    func disabledExcluded() {
        let registry = makeRegistry()
        registry.register(PaletteAction(
            id: "disabled",
            title: "Disabled",
            category: .general,
            isEnabled: { false },
            execute: { }
        ))

        #expect(registry.allActions(filter: nil).isEmpty)
    }

    @Test("recordUsage tracks recent action IDs")
    func recordUsage() {
        let registry = makeRegistry()
        registry.recordUsage(actionId: "first")
        registry.recordUsage(actionId: "second")

        let recents = registry.recentActionIds
        #expect(recents == ["second", "first"])
    }

    @Test("recents are capped at maxRecents")
    func recentsCapped() {
        let registry = ActionRegistry(
            defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!,
            recentsKey: "test.recents",
            maxRecents: 3
        )

        for i in 0..<5 {
            registry.recordUsage(actionId: "action-\(i)")
        }

        #expect(registry.recentActionIds.count == 3)
        #expect(registry.recentActionIds.first == "action-4")
    }

    @Test("recording duplicate moves it to front")
    func duplicateMovesFront() {
        let registry = makeRegistry()
        registry.recordUsage(actionId: "a")
        registry.recordUsage(actionId: "b")
        registry.recordUsage(actionId: "a")

        #expect(registry.recentActionIds == ["a", "b"])
    }
}
