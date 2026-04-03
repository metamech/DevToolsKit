import Foundation
import Observation

/// Generic health monitor for daemon processes with configurable polling and reconnection.
///
/// Monitors a daemon's health by periodically invoking a ``HealthCheckStrategy``.
/// Reports status changes via the observable ``status`` property and an optional callback.
///
/// ```swift
/// let monitor = DaemonHealthMonitor(
///     name: "my-daemon",
///     strategy: myHTTPCheck,
///     pollInterval: .seconds(30),
///     reconnectionPolicy: .default
/// )
/// monitor.start()
/// ```
///
/// - Since: 0.9.0
@MainActor @Observable
public final class DaemonHealthMonitor {

    /// Human-readable name for this monitor (used in logging/diagnostics).
    public let name: String

    /// The current health status.
    public private(set) var status: DaemonHealthStatus = .registered

    /// The most recent health check result.
    public private(set) var lastResult: HealthCheckResult?

    /// The number of consecutive failed checks.
    public private(set) var consecutiveFailures: Int = 0

    /// Callback invoked when the status changes.
    public var onStatusChanged: (@MainActor (DaemonHealthStatus) -> Void)?

    private let strategy: any HealthCheckStrategy
    private let pollInterval: Duration
    private let reconnectionPolicy: ReconnectionPolicy
    private var pollTask: Task<Void, Never>?
    private var reconnectAttempts: Int = 0

    /// Creates a daemon health monitor.
    ///
    /// - Parameters:
    ///   - name: Human-readable name for the monitored daemon.
    ///   - strategy: The health check strategy to use.
    ///   - pollInterval: How often to check health. Defaults to 30 seconds.
    ///   - reconnectionPolicy: Policy for reconnection attempts after failures.
    public init(
        name: String,
        strategy: any HealthCheckStrategy,
        pollInterval: Duration = .seconds(30),
        reconnectionPolicy: ReconnectionPolicy = .default
    ) {
        self.name = name
        self.strategy = strategy
        self.pollInterval = pollInterval
        self.reconnectionPolicy = reconnectionPolicy
    }

    /// Starts periodic health monitoring.
    ///
    /// Performs an initial check immediately, then polls at the configured interval.
    /// Safe to call multiple times — subsequent calls are no-ops.
    public func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            guard let self else { return }
            // Initial check
            await self.performCheck()
            while !Task.isCancelled {
                try? await Task.sleep(for: self.pollInterval)
                guard !Task.isCancelled else { break }
                await self.performCheck()
            }
        }
    }

    /// Stops health monitoring.
    public func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Perform a single health check immediately.
    public func checkNow() async {
        await performCheck()
    }

    /// Reset the monitor to its initial state.
    public func reset() {
        stop()
        status = .registered
        lastResult = nil
        consecutiveFailures = 0
        reconnectAttempts = 0
    }

    // MARK: - Private

    private func performCheck() async {
        let result = await strategy.check()
        lastResult = result
        let previousStatus = status

        switch result.status {
        case .running:
            consecutiveFailures = 0
            reconnectAttempts = 0
            status = .running
        case .degraded:
            consecutiveFailures = 0
            status = .degraded
        case .error, .notRegistered:
            consecutiveFailures += 1
            if consecutiveFailures >= reconnectionPolicy.maxAttempts {
                status = .error
            } else {
                // Still trying
                status = previousStatus == .running ? .degraded : previousStatus
            }
        case .registered:
            status = .registered
        }

        if status != previousStatus {
            onStatusChanged?(status)
        }
    }
}
