import Foundation
import SwiftUI
import SwiftUIFlowTesting
import Testing

@testable import DevToolsKitScreenCapture

extension ScreenCaptureStore: FlowModel {}

@Suite("ScreenCapturePanel Flow Tests")
@MainActor
struct ScreenCapturePanelFlowTests {

    // MARK: - Helpers

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlowTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func makeResult(
        mode: ScreenCaptureMode = .window,
        size: CGSize = CGSize(width: 800, height: 600),
        dataSize: Int = 64
    ) -> ScreenCaptureResult {
        ScreenCaptureResult(
            imageData: Data(repeating: 0xAA, count: dataSize),
            size: size,
            mode: mode,
            displayScale: 2.0
        )
    }

    // MARK: - Flow Tests

    @Test("Empty state → Add captures → Browse flow")
    func emptyToPopulatedFlow() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ScreenCaptureStore(storageDirectory: dir)

        FlowTester(name: "capture-history", model: store) { store in
            ScreenCapturePanelView(store: store)
        }
        .step("empty state") { _ in
            // Initial load — no captures yet
        } assert: { store in
            #expect(store.entries.isEmpty)
            #expect(store.filteredEntries.isEmpty)
            #expect(store.totalStorageBytes == 0)
        }
        .step("first capture saved") { store in
            try! store.save(self.makeResult(mode: .window))
        } assert: { store in
            #expect(store.entries.count == 1)
            #expect(store.entries.first?.mode == .window)
        }
        .step("second capture saved") { store in
            try! store.save(self.makeResult(mode: .area, size: CGSize(width: 1920, height: 1080)))
        } assert: { store in
            #expect(store.entries.count == 2)
            // Newest first
            #expect(store.entries.first?.mode == .area)
        }
        .step("third capture saved") { store in
            try! store.save(self.makeResult(mode: .fullScreen, size: CGSize(width: 2560, height: 1440)))
        } assert: { store in
            #expect(store.entries.count == 3)
            #expect(store.totalStorageBytes == 64 * 3)
        }
        .run(snapshotMode: .disabled)
    }

    @Test("Filter by mode flow")
    func filterByModeFlow() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ScreenCaptureStore(storageDirectory: dir)
        // Pre-populate
        try store.save(makeResult(mode: .window))
        try store.save(makeResult(mode: .area))
        try store.save(makeResult(mode: .fullScreen))
        try store.save(makeResult(mode: .window))

        FlowTester(name: "filter-mode", model: store) { store in
            ScreenCapturePanelView(store: store)
        }
        .step("all modes shown") { _ in
            // No filter applied
        } assert: { store in
            #expect(store.filterMode == nil)
            #expect(store.filteredEntries.count == 4)
        }
        .step("filter to window only") { store in
            store.filterMode = .window
        } assert: { store in
            #expect(store.filteredEntries.count == 2)
            #expect(store.filteredEntries.allSatisfy { $0.mode == .window })
        }
        .step("filter to area only") { store in
            store.filterMode = .area
        } assert: { store in
            #expect(store.filteredEntries.count == 1)
            #expect(store.filteredEntries.first?.mode == .area)
        }
        .step("filter to fullScreen") { store in
            store.filterMode = .fullScreen
        } assert: { store in
            #expect(store.filteredEntries.count == 1)
        }
        .step("clear filter") { store in
            store.filterMode = nil
        } assert: { store in
            #expect(store.filteredEntries.count == 4)
        }
        .run(snapshotMode: .disabled)
    }

    @Test("Delete capture flow")
    func deleteCaptureFlow() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ScreenCaptureStore(storageDirectory: dir)
        let entry1 = try store.save(makeResult(mode: .window))
        let entry2 = try store.save(makeResult(mode: .area))
        let entry3 = try store.save(makeResult(mode: .fullScreen))

        FlowTester(name: "delete-capture", model: store) { store in
            ScreenCapturePanelView(store: store)
        }
        .step("three captures present") { _ in
        } assert: { store in
            #expect(store.entries.count == 3)
        }
        .step("delete one capture") { store in
            store.delete(id: entry2.id)
        } assert: { store in
            #expect(store.entries.count == 2)
            #expect(!store.entries.contains { $0.id == entry2.id })
            // Files should be removed
            let jsonExists = FileManager.default.fileExists(
                atPath: dir.appendingPathComponent("\(entry2.id.uuidString).json").path
            )
            #expect(!jsonExists)
        }
        .step("delete remaining via batch") { store in
            store.delete(ids: [entry1.id, entry3.id])
        } assert: { store in
            #expect(store.entries.isEmpty)
            #expect(store.totalStorageBytes == 0)
        }
        .run(snapshotMode: .disabled)
    }

    @Test("Filter by date range flow")
    func filterByDateRangeFlow() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ScreenCaptureStore(storageDirectory: dir)

        let oldResult = ScreenCaptureResult(
            imageData: Data(repeating: 0, count: 32),
            size: CGSize(width: 100, height: 100),
            mode: .window,
            timestamp: Date(timeIntervalSince1970: 1_000_000),
            displayScale: 1.0
        )
        let recentResult = ScreenCaptureResult(
            imageData: Data(repeating: 0, count: 32),
            size: CGSize(width: 100, height: 100),
            mode: .area,
            timestamp: Date(timeIntervalSince1970: 2_000_000),
            displayScale: 1.0
        )

        try store.save(oldResult)
        try store.save(recentResult)

        let rangeStart = Date(timeIntervalSince1970: 1_500_000)
        let rangeEnd = Date(timeIntervalSince1970: 2_500_000)
        let recentRange: ClosedRange<Date> = rangeStart...rangeEnd

        let tester = FlowTester(name: "filter-date", model: store) { store in
            ScreenCapturePanelView(store: store)
        }
        tester.step("no date filter") { _ in
        } assert: { store in
            #expect(store.filteredEntries.count == 2)
        }
        tester.step("filter to recent only") { store in
            store.filterDateRange = recentRange
        } assert: { store in
            #expect(store.filteredEntries.count == 1)
            #expect(store.filteredEntries.first?.mode == .area)
        }
        tester.step("clear date filter") { store in
            store.filterDateRange = nil
        } assert: { store in
            #expect(store.filteredEntries.count == 2)
        }
        tester.run(snapshotMode: .disabled)
    }

    @Test("Max captures trimming flow")
    func maxCapturesTrimmingFlow() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ScreenCaptureStore(storageDirectory: dir, maxCaptures: 3)

        FlowTester(name: "trimming", model: store) { store in
            ScreenCapturePanelView(store: store)
        }
        .step("add three captures") { store in
            try! store.save(self.makeResult(mode: .window))
            try! store.save(self.makeResult(mode: .area))
            try! store.save(self.makeResult(mode: .fullScreen))
        } assert: { store in
            #expect(store.entries.count == 3)
        }
        .step("add fourth — oldest trimmed") { store in
            try! store.save(self.makeResult(mode: .window))
        } assert: { store in
            #expect(store.entries.count == 3)
            // Newest should be first
            #expect(store.entries.first?.mode == .window)
        }
        .step("add fifth — still capped at 3") { store in
            try! store.save(self.makeResult(mode: .area))
        } assert: { store in
            #expect(store.entries.count == 3)
            #expect(store.entries.first?.mode == .area)
        }
        .run(snapshotMode: .disabled)
    }

    @Test("Reload persistence flow")
    func reloadPersistenceFlow() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        // Phase 1: Save captures with one store
        let store1 = ScreenCaptureStore(storageDirectory: dir)
        try store1.save(makeResult(mode: .window))
        try store1.save(makeResult(mode: .area))

        // Phase 2: New store loads from same directory
        let store2 = ScreenCaptureStore(storageDirectory: dir)

        FlowTester(name: "persistence", model: store2) { store in
            ScreenCapturePanelView(store: store)
        }
        .step("new store starts empty") { _ in
        } assert: { store in
            #expect(store.entries.isEmpty)
        }
        .step("load from disk") { store in
            try! store.loadAll()
        } assert: { store in
            #expect(store.entries.count == 2)
            // Newest first
            #expect(store.entries.first?.mode == .area)
            #expect(store.entries.last?.mode == .window)
        }
        .run(snapshotMode: .disabled)
    }

    @Test("Image data retrieval flow")
    func imageDataRetrievalFlow() throws {
        let dir = try makeTempDirectory()
        defer { cleanup(dir) }

        let store = ScreenCaptureStore(storageDirectory: dir)
        var savedEntry: ScreenCaptureEntry?

        FlowTester(name: "image-data", model: store) { store in
            ScreenCapturePanelView(store: store)
        }
        .step("save capture with known data") { store in
            savedEntry = try! store.save(self.makeResult(dataSize: 128))
        } assert: { store in
            #expect(savedEntry != nil)
            #expect(store.entries.count == 1)
        }
        .step("retrieve full image data") { _ in
            // Read-only step — just verify data access
        } assert: { store in
            guard let entry = savedEntry else { return }
            let data = store.imageData(for: entry)
            #expect(data != nil)
            #expect(data?.count == 128)
        }
        .step("retrieve thumbnail data") { _ in
        } assert: { store in
            guard let entry = savedEntry else { return }
            // Thumbnail may be nil with synthetic data, but the accessor shouldn't crash
            _ = store.thumbnailData(for: entry)
        }
        .step("delete removes image files") { store in
            guard let entry = savedEntry else { return }
            store.delete(id: entry.id)
        } assert: { store in
            guard let entry = savedEntry else { return }
            let data = store.imageData(for: entry)
            #expect(data == nil)
        }
        .run(snapshotMode: .disabled)
    }
}
