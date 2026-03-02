import Testing

@testable import DevToolsKitLogging

@Suite
struct LogColumnTests {
    @Test func shortStringReturnedAsIs() {
        // A short source fits in a wide column
        let result = truncateReverseDNS("network", fitting: 300)
        #expect(result == "network")
    }

    @Test func longSourceStripsLeadingComponents() {
        // 5-component string in a narrow column should drop leading components
        let source = "com.metamech.maccad.canvas.view"
        let result = truncateReverseDNS(source, fitting: 160)
        // Should have stripped at least "com" and possibly "metamech"
        #expect(!result.hasPrefix("com."))
        #expect(result.hasSuffix("canvas.view"))
    }

    @Test func twoComponentStringNeverReduced() {
        let source = "canvas.view"
        let result = truncateReverseDNS(source, fitting: 10)
        #expect(result == "canvas.view")
    }

    @Test func singleComponentReturnedAsIs() {
        let result = truncateReverseDNS("network", fitting: 10)
        #expect(result == "network")
    }

    @Test func fitsExactly() {
        // A source that fits the column width should be returned as-is
        let result = truncateReverseDNS("com.example.app", fitting: 500)
        #expect(result == "com.example.app")
    }
}
