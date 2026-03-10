import Foundation
import Testing

@testable import DevToolsKitScreenCapture

@Suite("ScreenCaptureResult Tests")
struct ScreenCaptureResultTests {
    @Test("Stores all properties correctly")
    func properties() {
        let data = Data([0x89, 0x50, 0x4E, 0x47])  // PNG magic bytes
        let date = Date(timeIntervalSince1970: 1_000_000)
        let result = ScreenCaptureResult(
            imageData: data,
            size: CGSize(width: 800, height: 600),
            mode: .window,
            timestamp: date,
            displayScale: 2.0
        )

        #expect(result.imageData == data)
        #expect(result.size.width == 800)
        #expect(result.size.height == 600)
        #expect(result.mode == .window)
        #expect(result.timestamp == date)
        #expect(result.displayScale == 2.0)
    }

    @Test("Default timestamp is approximately now")
    func defaultTimestamp() {
        let before = Date()
        let result = ScreenCaptureResult(
            imageData: Data(),
            size: CGSize(width: 100, height: 100),
            mode: .fullScreen
        )
        let after = Date()

        #expect(result.timestamp >= before)
        #expect(result.timestamp <= after)
    }

    @Test("Default display scale is 1.0")
    func defaultScale() {
        let result = ScreenCaptureResult(
            imageData: Data(),
            size: CGSize(width: 100, height: 100),
            mode: .area
        )
        #expect(result.displayScale == 1.0)
    }
}
