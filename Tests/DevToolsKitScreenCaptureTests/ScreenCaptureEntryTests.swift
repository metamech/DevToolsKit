import Foundation
import Testing

@testable import DevToolsKitScreenCapture

@Suite("ScreenCaptureEntry")
struct ScreenCaptureEntryTests {
    @Test("Memberwise init sets all properties")
    func memberwiseInit() {
        let id = UUID()
        let date = Date()
        let entry = ScreenCaptureEntry(
            id: id,
            timestamp: date,
            mode: .window,
            imageSize: CGSize(width: 1920, height: 1080),
            displayScale: 2.0,
            imageDataSize: 1024
        )

        #expect(entry.id == id)
        #expect(entry.timestamp == date)
        #expect(entry.mode == .window)
        #expect(entry.imageSize == CGSize(width: 1920, height: 1080))
        #expect(entry.displayScale == 2.0)
        #expect(entry.imageDataSize == 1024)
    }

    @Test("Init from ScreenCaptureResult extracts metadata")
    func initFromResult() {
        let imageData = Data(repeating: 0xFF, count: 256)
        let result = ScreenCaptureResult(
            imageData: imageData,
            size: CGSize(width: 800, height: 600),
            mode: .area,
            displayScale: 1.5
        )

        let entry = ScreenCaptureEntry(result: result)

        #expect(entry.mode == .area)
        #expect(entry.imageSize == CGSize(width: 800, height: 600))
        #expect(entry.displayScale == 1.5)
        #expect(entry.imageDataSize == 256)
    }

    @Test("Codable round-trip preserves all properties")
    func codableRoundTrip() throws {
        let entry = ScreenCaptureEntry(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            mode: .fullScreen,
            imageSize: CGSize(width: 2560, height: 1440),
            displayScale: 2.0,
            imageDataSize: 4096
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ScreenCaptureEntry.self, from: data)

        #expect(decoded.id == entry.id)
        #expect(decoded.timestamp == entry.timestamp)
        #expect(decoded.mode == entry.mode)
        #expect(decoded.imageSize == entry.imageSize)
        #expect(decoded.displayScale == entry.displayScale)
        #expect(decoded.imageDataSize == entry.imageDataSize)
    }

    @Test("Identifiable uses UUID")
    func identifiable() {
        let entry1 = ScreenCaptureEntry(
            timestamp: Date(),
            mode: .window,
            imageSize: .zero,
            displayScale: 1.0,
            imageDataSize: 0
        )
        let entry2 = ScreenCaptureEntry(
            id: entry1.id,
            timestamp: Date(),
            mode: .area,
            imageSize: .zero,
            displayScale: 2.0,
            imageDataSize: 100
        )

        #expect(entry1.id == entry2.id)
    }
}
