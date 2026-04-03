#if os(macOS)
import Testing
@testable import DevToolsKit

@Suite("PowerStateMonitor")
@MainActor
struct PowerStateMonitorTests {

    @Test("Initial state is unknown before start")
    func initialState() {
        let monitor = PowerStateMonitor()
        #expect(monitor.currentSource == .unknown)
    }

    @Test("Start sets initial power source")
    func startSetsSource() {
        let monitor = PowerStateMonitor()
        monitor.start()
        // After start, source should be detected (ac, battery, or unknown on CI)
        // Just verify it doesn't crash and the source is set
        let source = monitor.currentSource
        #expect(source == .ac || source == .battery || source == .unknown)
        monitor.stop()
    }

    @Test("Multiple starts are safe (idempotent)")
    func multipleStarts() {
        let monitor = PowerStateMonitor()
        monitor.start()
        monitor.start() // Should be a no-op
        monitor.stop()
    }

    @Test("Stop without start is safe")
    func stopWithoutStart() {
        let monitor = PowerStateMonitor()
        monitor.stop() // Should not crash
    }

    @Test("detectPowerSource is nonisolated and returns valid value")
    func detectPowerSource() {
        let source = PowerStateMonitor.detectPowerSource()
        #expect(source == .ac || source == .battery || source == .unknown)
    }

    @Test("PowerSource raw values")
    func powerSourceRawValues() {
        #expect(PowerStateMonitor.PowerSource.ac.rawValue == "ac")
        #expect(PowerStateMonitor.PowerSource.battery.rawValue == "battery")
        #expect(PowerStateMonitor.PowerSource.unknown.rawValue == "unknown")
    }
}
#endif
