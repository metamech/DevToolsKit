import Foundation
import Testing

@testable import DevToolsKitScreenCapture

@Suite("ScreenCaptureExporter Tests")
struct ScreenCaptureExporterTests {
    @Test("ScreenCaptureFormat has all cases")
    func formatCases() {
        let cases = ScreenCaptureFormat.allCases
        #expect(cases.count == 3)
        #expect(cases.contains(.png))
        #expect(cases.contains(.jpeg))
        #expect(cases.contains(.tiff))
    }

    @Test("Format raw values are correct")
    func formatRawValues() {
        #expect(ScreenCaptureFormat.png.rawValue == "png")
        #expect(ScreenCaptureFormat.jpeg.rawValue == "jpeg")
        #expect(ScreenCaptureFormat.tiff.rawValue == "tiff")
    }

    @Test("PNG data passthrough returns same data")
    func pngPassthrough() throws {
        let originalData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])
        let result = ScreenCaptureResult(
            imageData: originalData,
            size: CGSize(width: 100, height: 100),
            mode: .window
        )

        let output = try ScreenCaptureExporter.data(from: result, format: .png)
        #expect(output == originalData)
    }

    @Test("Save writes file to disk")
    func saveToFile() throws {
        let data = Data([0x89, 0x50, 0x4E, 0x47])
        let result = ScreenCaptureResult(
            imageData: data,
            size: CGSize(width: 10, height: 10),
            mode: .fullScreen
        )

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")

        try ScreenCaptureExporter.save(result, to: tempURL, format: .png)

        let saved = try Data(contentsOf: tempURL)
        #expect(saved == data)

        try FileManager.default.removeItem(at: tempURL)
    }
}
