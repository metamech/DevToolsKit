import Foundation
import Testing

@testable import DevToolsKitIssueCapture

@Suite("IssueCaptureStore Tests")
@MainActor
struct IssueCaptureStoreTests {
    private func makeStore(maxCaptures: Int? = nil) -> IssueCaptureStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IssueCaptureStoreTests-\(UUID().uuidString)")
        return IssueCaptureStore(storageDirectory: dir, maxCaptures: maxCaptures)
    }

    private func makeCapture(
        providerID: String = "test",
        tags: [String] = [],
        notes: String? = nil
    ) -> IssueCapture {
        IssueCapture(
            providerID: providerID,
            providerName: "Test",
            capturedState: ["status": "working"],
            expectedState: ["status": "idle"],
            notes: notes,
            tags: tags
        )
    }

    private func cleanup(_ store: IssueCaptureStore) {
        try? FileManager.default.removeItem(at: store.storageDirectory)
    }

    @Test("Save and load round-trip")
    func saveAndLoad() throws {
        let store = makeStore()
        defer { cleanup(store) }

        let capture = makeCapture(tags: ["ui"])
        try store.save(capture)

        #expect(store.captures.count == 1)
        #expect(store.captures[0].id == capture.id)

        // Create a new store pointing to same dir and load
        let store2 = IssueCaptureStore(storageDirectory: store.storageDirectory)
        try store2.loadAll()

        #expect(store2.captures.count == 1)
        #expect(store2.captures[0].id == capture.id)
        #expect(store2.captures[0].tags == ["ui"])
    }

    @Test("Delete removes from store and disk")
    func delete() throws {
        let store = makeStore()
        defer { cleanup(store) }

        let capture = makeCapture()
        try store.save(capture)
        #expect(store.captures.count == 1)

        store.delete(id: capture.id)
        #expect(store.captures.isEmpty)

        // Verify file is gone
        let fileURL = store.storageDirectory.appendingPathComponent("\(capture.id.uuidString).json")
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("Delete multiple captures")
    func deleteMultiple() throws {
        let store = makeStore()
        defer { cleanup(store) }

        let c1 = makeCapture()
        let c2 = makeCapture()
        let c3 = makeCapture()
        try store.save(c1)
        try store.save(c2)
        try store.save(c3)

        store.delete(ids: [c1.id, c3.id])
        #expect(store.captures.count == 1)
        #expect(store.captures[0].id == c2.id)
    }

    @Test("Filter by provider ID")
    func filterByProvider() throws {
        let store = makeStore()
        defer { cleanup(store) }

        try store.save(makeCapture(providerID: "alpha"))
        try store.save(makeCapture(providerID: "beta"))
        try store.save(makeCapture(providerID: "alpha"))

        store.filterProviderID = "alpha"
        #expect(store.filteredCaptures.count == 2)

        store.filterProviderID = "beta"
        #expect(store.filteredCaptures.count == 1)

        store.filterProviderID = nil
        #expect(store.filteredCaptures.count == 3)
    }

    @Test("Filter by tag")
    func filterByTag() throws {
        let store = makeStore()
        defer { cleanup(store) }

        try store.save(makeCapture(tags: ["ui", "state"]))
        try store.save(makeCapture(tags: ["network"]))
        try store.save(makeCapture(tags: ["ui"]))

        store.filterTag = "ui"
        #expect(store.filteredCaptures.count == 2)

        store.filterTag = "network"
        #expect(store.filteredCaptures.count == 1)
    }

    @Test("Search text filter")
    func searchFilter() throws {
        let store = makeStore()
        defer { cleanup(store) }

        try store.save(makeCapture(notes: "Button didn't respond"))
        try store.save(makeCapture(notes: "State was wrong"))
        try store.save(makeCapture(notes: nil))

        store.searchText = "button"
        #expect(store.filteredCaptures.count == 1)

        store.searchText = "wrong"
        #expect(store.filteredCaptures.count == 1)

        store.searchText = ""
        #expect(store.filteredCaptures.count == 3)
    }

    @Test("Max captures enforces FIFO trimming")
    func maxCaptures() throws {
        let store = makeStore(maxCaptures: 2)
        defer { cleanup(store) }

        let c1 = makeCapture()
        let c2 = makeCapture()
        let c3 = makeCapture()

        try store.save(c1)
        try store.save(c2)
        #expect(store.captures.count == 2)

        try store.save(c3)
        #expect(store.captures.count == 2)
        // Newest first, so c3 and c2 should remain
        #expect(store.captures[0].id == c3.id)
        #expect(store.captures[1].id == c2.id)
    }

    @Test("Known provider IDs")
    func knownProviderIDs() throws {
        let store = makeStore()
        defer { cleanup(store) }

        try store.save(makeCapture(providerID: "beta"))
        try store.save(makeCapture(providerID: "alpha"))
        try store.save(makeCapture(providerID: "beta"))

        #expect(store.knownProviderIDs == ["alpha", "beta"])
    }

    @Test("Known tags")
    func knownTags() throws {
        let store = makeStore()
        defer { cleanup(store) }

        try store.save(makeCapture(tags: ["ui", "state"]))
        try store.save(makeCapture(tags: ["network", "ui"]))

        #expect(store.knownTags == ["network", "state", "ui"])
    }

    @Test("Common expected values analysis")
    func commonExpectedValues() throws {
        let store = makeStore()
        defer { cleanup(store) }

        try store.save(makeCapture()) // expectedState: ["status": "idle"]
        try store.save(makeCapture())
        try store.save(IssueCapture(
            providerID: "test",
            providerName: "Test",
            capturedState: ["status": "working"],
            expectedState: ["status": "error"]
        ))

        let common = store.commonExpectedValues(fieldID: "status")
        #expect(common.count == 2)
        #expect(common[0].value == "idle")
        #expect(common[0].count == 2)
        #expect(common[1].value == "error")
        #expect(common[1].count == 1)
    }

    @Test("Export filtered produces valid JSON")
    func exportFiltered() throws {
        let store = makeStore()
        defer { cleanup(store) }

        try store.save(makeCapture(providerID: "a", tags: ["ui"]))
        try store.save(makeCapture(providerID: "b"))

        store.filterProviderID = "a"
        let data = try store.exportFiltered()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exported = try decoder.decode([IssueCapture].self, from: data)
        #expect(exported.count == 1)
        #expect(exported[0].providerID == "a")
        #expect(exported[0].screenshotData == nil) // stripped
    }
}
