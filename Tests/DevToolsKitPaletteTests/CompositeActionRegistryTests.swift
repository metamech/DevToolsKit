import Foundation
import Testing
@testable import DevToolsKitPalette

@MainActor
@Suite("CompositeActionRegistry")
struct CompositeActionRegistryTests {

    private func makeRegistry() -> ActionRegistry {
        ActionRegistry(
            defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!,
            recentsKey: "test.recents.\(UUID().uuidString)"
        )
    }

    @Test("merges primary and global actions")
    func mergesPrimaryAndGlobal() {
        let primary = makeRegistry()
        let global = makeRegistry()
        let composite = CompositeActionRegistry(primary: primary, global: global)

        primary.register(PaletteAction(id: "local", title: "Local", category: .general, execute: { }))
        global.register(PaletteAction(id: "global", title: "Global", category: .general, execute: { }))

        let results = composite.allActions(filter: nil)
        #expect(results.count == 2)
        let ids = Set(results.map(\.id))
        #expect(ids == ["local", "global"])
    }

    @Test("primary takes precedence over global with same id")
    func primaryPrecedence() {
        let primary = makeRegistry()
        let global = makeRegistry()
        let composite = CompositeActionRegistry(primary: primary, global: global)

        primary.register(PaletteAction(id: "shared", title: "Primary Version", category: .general, execute: { }))
        global.register(PaletteAction(id: "shared", title: "Global Version", category: .general, execute: { }))

        let results = composite.allActions(filter: nil)
        #expect(results.count == 1)
        #expect(results.first?.title == "Primary Version")
    }

    @Test("writes go to primary")
    func writesGoToPrimary() {
        let primary = makeRegistry()
        let global = makeRegistry()
        let composite = CompositeActionRegistry(primary: primary, global: global)

        composite.register(PaletteAction(id: "new", title: "New", category: .general, execute: { }))

        #expect(primary.allActions(filter: nil).count == 1)
        #expect(global.allActions(filter: nil).isEmpty)
    }

    @Test("unregister removes from primary")
    func unregisterFromPrimary() {
        let primary = makeRegistry()
        let global = makeRegistry()
        let composite = CompositeActionRegistry(primary: primary, global: global)

        composite.register(PaletteAction(id: "rm", title: "Remove", category: .general, execute: { }))
        composite.unregister(id: "rm")

        #expect(primary.allActions(filter: nil).isEmpty)
    }

    @Test("recents come from primary")
    func recentsFromPrimary() {
        let primary = makeRegistry()
        let global = makeRegistry()
        let composite = CompositeActionRegistry(primary: primary, global: global)

        composite.recordUsage(actionId: "test-action")
        #expect(composite.recentActionIds == ["test-action"])
        #expect(primary.recentActionIds == ["test-action"])
    }
}
