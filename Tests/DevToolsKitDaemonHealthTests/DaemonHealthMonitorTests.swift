import Foundation
import Testing
@testable import DevToolsKitDaemonHealth

// MARK: - Mock Strategy

struct MockHealthCheckStrategy: HealthCheckStrategy {
    let results: [HealthCheckResult]
    let callCounter: CallCounter

    init(results: [HealthCheckResult]) {
        self.results = results
        self.callCounter = CallCounter()
    }

    func check() async -> HealthCheckResult {
        let index = callCounter.increment()
        if index < results.count {
            return results[index]
        }
        return results.last ?? .healthy()
    }
}

final class CallCounter: @unchecked Sendable {
    private var _count = 0
    private let lock = NSLock()

    func increment() -> Int {
        lock.lock()
        let current = _count
        _count += 1
        lock.unlock()
        return current
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _count
    }
}

@Suite("DaemonHealthStatus")
struct DaemonHealthStatusTests {

    @Test("Running and degraded are usable")
    func usableStates() {
        #expect(DaemonHealthStatus.running.isUsable)
        #expect(DaemonHealthStatus.degraded.isUsable)
    }

    @Test("Other states are not usable")
    func unusableStates() {
        #expect(!DaemonHealthStatus.notRegistered.isUsable)
        #expect(!DaemonHealthStatus.registered.isUsable)
        #expect(!DaemonHealthStatus.error.isUsable)
    }
}

@Suite("HealthCheckResult")
struct HealthCheckResultTests {

    @Test("Convenience constructors")
    func convenience() {
        let healthy = HealthCheckResult.healthy(message: "OK")
        #expect(healthy.status == .running)

        let error = HealthCheckResult.error("Failed")
        #expect(error.status == .error)
        #expect(error.message == "Failed")

        let degraded = HealthCheckResult.degraded("Slow")
        #expect(degraded.status == .degraded)
    }
}

@Suite("ReconnectionPolicy")
struct ReconnectionPolicyTests {

    @Test("Default policy values")
    func defaults() {
        let policy = ReconnectionPolicy.default
        #expect(policy.maxAttempts == 3)
        #expect(policy.backoffMultiplier == 2.0)
    }

    @Test("Exponential backoff delay")
    func backoffDelay() {
        let policy = ReconnectionPolicy(
            baseDelay: .seconds(1),
            maxDelay: .seconds(30),
            backoffMultiplier: 2.0
        )
        let delay0 = policy.delay(forAttempt: 0) // 1s
        let delay1 = policy.delay(forAttempt: 1) // 2s
        let delay2 = policy.delay(forAttempt: 2) // 4s
        #expect(delay0 == .milliseconds(1000))
        #expect(delay1 == .milliseconds(2000))
        #expect(delay2 == .milliseconds(4000))
    }

    @Test("Delay is capped at maxDelay")
    func delayCapped() {
        let policy = ReconnectionPolicy(
            baseDelay: .seconds(10),
            maxDelay: .seconds(15),
            backoffMultiplier: 2.0
        )
        let delay1 = policy.delay(forAttempt: 1) // 20s would be > 15s max
        #expect(delay1 == .milliseconds(15000))
    }
}

@Suite("DaemonHealthMonitor")
@MainActor
struct DaemonHealthMonitorTests {

    @Test("Initial state is registered")
    func initialState() {
        let strategy = MockHealthCheckStrategy(results: [.healthy()])
        let monitor = DaemonHealthMonitor(name: "test", strategy: strategy)
        #expect(monitor.status == .registered)
        #expect(monitor.consecutiveFailures == 0)
    }

    @Test("checkNow updates status to running")
    func checkNowHealthy() async {
        let strategy = MockHealthCheckStrategy(results: [.healthy()])
        let monitor = DaemonHealthMonitor(name: "test", strategy: strategy)
        await monitor.checkNow()
        #expect(monitor.status == .running)
        #expect(monitor.lastResult?.status == .running)
    }

    @Test("checkNow tracks consecutive failures")
    func consecutiveFailures() async {
        let strategy = MockHealthCheckStrategy(results: [
            .error("fail1"),
            .error("fail2"),
            .error("fail3"),
        ])
        let monitor = DaemonHealthMonitor(
            name: "test",
            strategy: strategy,
            reconnectionPolicy: ReconnectionPolicy(maxAttempts: 3)
        )
        await monitor.checkNow()
        #expect(monitor.consecutiveFailures == 1)
        await monitor.checkNow()
        #expect(monitor.consecutiveFailures == 2)
        await monitor.checkNow()
        #expect(monitor.consecutiveFailures == 3)
        #expect(monitor.status == .error)
    }

    @Test("Recovery resets consecutive failures")
    func recovery() async {
        let strategy = MockHealthCheckStrategy(results: [
            .error("fail"),
            .healthy(),
        ])
        let monitor = DaemonHealthMonitor(name: "test", strategy: strategy)
        await monitor.checkNow()
        #expect(monitor.consecutiveFailures == 1)
        await monitor.checkNow()
        #expect(monitor.consecutiveFailures == 0)
        #expect(monitor.status == .running)
    }

    @Test("Reset clears all state")
    func resetState() async {
        let strategy = MockHealthCheckStrategy(results: [.healthy()])
        let monitor = DaemonHealthMonitor(name: "test", strategy: strategy)
        await monitor.checkNow()
        #expect(monitor.status == .running)
        monitor.reset()
        #expect(monitor.status == .registered)
        #expect(monitor.lastResult == nil)
        #expect(monitor.consecutiveFailures == 0)
    }

    @Test("Status change callback fires")
    func statusChangeCallback() async {
        let strategy = MockHealthCheckStrategy(results: [.healthy()])
        let monitor = DaemonHealthMonitor(name: "test", strategy: strategy)
        var received: DaemonHealthStatus?
        monitor.onStatusChanged = { status in received = status }
        await monitor.checkNow()
        #expect(received == .running)
    }
}
