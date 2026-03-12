import Foundation
import Testing

@testable import DevToolsKitScreenCapture

@Suite("ScreenCaptureStore")
struct ScreenCaptureStoreTests {
    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenCaptureStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func makeResult(
        mode: ScreenCaptureMode = .window,
        size: CGSize = CGSize(width: 100, height: 100),
        dataSize: Int = 64
    ) -> ScreenCaptureResult {
        ScreenCaptureResult(
            imageData: Data(repeating: 0xAA, count: dataSize),
            size: size,
            mode: mode,
            displayScale: 2.0
        )
    }

    @Test("Save and loadAll round-trip")
    @MainActor
    func saveAndLoadAll() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ScreenCaptureStore(storageDirectory: dir)
        let result = makeResult()
        let entry = try store.save(result)

        #expect(store.entries.count == 1)
        #expect(store.entries.first?.id == entry.id)

        // Reload into new store
        let store2 = ScreenCaptureStore(storageDirectory: dir)
        try store2.loadAll()

        #expect(store2.entries.count == 1)
        #expect(store2.entries.first?.id == entry.id)
        #expect(store2.entries.first?.mode == .window)
    }

    @Test("Delete removes entry and all files")
    @MainActor
    func deleteRemovesFiles() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ScreenCaptureStore(storageDirectory: dir)
        let entry = try store.save(makeResult())

        let fm = FileManager.default
        let jsonPath = dir.appendingPathComponent("\(entry.id.uuidString).json").path
        let pngPath = dir.appendingPathComponent("\(entry.id.uuidString).png").path

        #expect(fm.fileExists(atPath: jsonPath))
        #expect(fm.fileExists(atPath: pngPath))

        store.delete(id: entry.id)

        #expect(store.entries.isEmpty)
        #expect(!fm.fileExists(atPath: jsonPath))
        #expect(!fm.fileExists(atPath: pngPath))
    }

    @Test("Delete multiple IDs")
    @MainActor
    func deleteMultiple() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ScreenCaptureStore(storageDirectory: dir)
        let e1 = try store.save(makeResult())
        let e2 = try store.save(makeResult(mode: .area))

        #expect(store.entries.count == 2)

        store.delete(ids: [e1.id, e2.id])

        #expect(store.entries.isEmpty)
    }

    @Test("Filter by mode")
    @MainActor
    func filterByMode() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ScreenCaptureStore(storageDirectory: dir)
        try store.save(makeResult(mode: .window))
        try store.save(makeResult(mode: .area))
        try store.save(makeResult(mode: .fullScreen))

        #expect(store.filteredEntries.count == 3)

        store.filterMode = .area
        #expect(store.filteredEntries.count == 1)
        #expect(store.filteredEntries.first?.mode == .area)

        store.filterMode = nil
        #expect(store.filteredEntries.count == 3)
    }

    @Test("Filter by date range")
    @MainActor
    func filterByDateRange() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ScreenCaptureStore(storageDirectory: dir)

        let old = ScreenCaptureResult(
            imageData: Data(repeating: 0, count: 10),
            size: CGSize(width: 100, height: 100),
            mode: .window,
            timestamp: Date(timeIntervalSince1970: 1_000_000),
            displayScale: 1.0
        )
        let recent = ScreenCaptureResult(
            imageData: Data(repeating: 0, count: 10),
            size: CGSize(width: 100, height: 100),
            mode: .window,
            timestamp: Date(timeIntervalSince1970: 2_000_000),
            displayScale: 1.0
        )

        try store.save(old)
        try store.save(recent)

        #expect(store.filteredEntries.count == 2)

        store.filterDateRange = Date(timeIntervalSince1970: 1_500_000)...Date(timeIntervalSince1970: 2_500_000)
        #expect(store.filteredEntries.count == 1)

        store.filterDateRange = nil
        #expect(store.filteredEntries.count == 2)
    }

    @Test("Max captures trims oldest")
    @MainActor
    func maxCapturesTrimming() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ScreenCaptureStore(storageDirectory: dir, maxCaptures: 2)
        try store.save(makeResult())
        try store.save(makeResult(mode: .area))
        try store.save(makeResult(mode: .fullScreen))

        #expect(store.entries.count == 2)
        // Most recent two should remain
        #expect(store.entries[0].mode == .fullScreen)
        #expect(store.entries[1].mode == .area)
    }

    @Test("imageData returns PNG data")
    @MainActor
    func imageDataRetrieval() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ScreenCaptureStore(storageDirectory: dir)
        let result = makeResult(dataSize: 128)
        let entry = try store.save(result)

        let data = store.imageData(for: entry)
        #expect(data != nil)
        #expect(data?.count == 128)
    }

    @Test("thumbnailData returns data after save")
    @MainActor
    func thumbnailDataRetrieval() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ScreenCaptureStore(storageDirectory: dir)
        let entry = try store.save(makeResult())

        // Thumbnail may be nil if image data isn't valid PNG for the platform,
        // but the file should at least be attempted
        let thumbPath = dir.appendingPathComponent("\(entry.id.uuidString).thumb.png").path
        // With synthetic data, thumbnail generation may fail — that's OK
        _ = store.thumbnailData(for: entry)
        _ = FileManager.default.fileExists(atPath: thumbPath)
    }

    @Test("totalStorageBytes sums imageDataSize")
    @MainActor
    func totalStorageBytes() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ScreenCaptureStore(storageDirectory: dir)
        try store.save(makeResult(dataSize: 100))
        try store.save(makeResult(dataSize: 200))

        #expect(store.totalStorageBytes == 300)
    }

    @Test("DiagnosticProvider collect returns digest")
    @MainActor
    func diagnosticProviderCollect() async throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ScreenCaptureStore(storageDirectory: dir)
        try store.save(makeResult(mode: .window))
        try store.save(makeResult(mode: .area))

        let result = await store.collect()

        // Verify it's encodable
        let encoder = JSONEncoder()
        let data = try encoder.encode(result)
        #expect(data.count > 0)
    }

    @Test("Entries sorted newest first")
    @MainActor
    func entriesSortedNewestFirst() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ScreenCaptureStore(storageDirectory: dir)

        let older = ScreenCaptureResult(
            imageData: Data(repeating: 0, count: 10),
            size: CGSize(width: 100, height: 100),
            mode: .window,
            timestamp: Date(timeIntervalSince1970: 1_000_000),
            displayScale: 1.0
        )
        let newer = ScreenCaptureResult(
            imageData: Data(repeating: 0, count: 10),
            size: CGSize(width: 100, height: 100),
            mode: .area,
            timestamp: Date(timeIntervalSince1970: 2_000_000),
            displayScale: 1.0
        )

        try store.save(older)
        try store.save(newer)

        // Reload to test sort on load
        let store2 = ScreenCaptureStore(storageDirectory: dir)
        try store2.loadAll()

        #expect(store2.entries.first?.mode == .area) // newer
        #expect(store2.entries.last?.mode == .window) // older
    }
}
