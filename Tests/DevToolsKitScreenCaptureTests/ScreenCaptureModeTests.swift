import Testing

@testable import DevToolsKitScreenCapture

@Suite("ScreenCaptureMode Tests")
struct ScreenCaptureModeTests {
    @Test("All cases are present")
    func allCases() {
        let cases = ScreenCaptureMode.allCases
        #expect(cases.count == 3)
        #expect(cases.contains(.window))
        #expect(cases.contains(.area))
        #expect(cases.contains(.fullScreen))
    }

    @Test("Raw values are correct")
    func rawValues() {
        #expect(ScreenCaptureMode.window.rawValue == "window")
        #expect(ScreenCaptureMode.area.rawValue == "area")
        #expect(ScreenCaptureMode.fullScreen.rawValue == "fullScreen")
    }

    @Test("Initializes from raw value")
    func initFromRawValue() {
        #expect(ScreenCaptureMode(rawValue: "window") == .window)
        #expect(ScreenCaptureMode(rawValue: "area") == .area)
        #expect(ScreenCaptureMode(rawValue: "fullScreen") == .fullScreen)
        #expect(ScreenCaptureMode(rawValue: "invalid") == nil)
    }
}
