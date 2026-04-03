import Foundation

/// Unified health status for a monitored daemon process.
///
/// - Since: 0.9.0
public enum DaemonHealthStatus: String, Sendable, Equatable, CaseIterable {
    /// The daemon has not been registered with the monitor.
    case notRegistered
    /// The daemon is registered but has not been checked yet.
    case registered
    /// The daemon is running and healthy.
    case running
    /// The daemon is running but reporting degraded performance.
    case degraded
    /// The daemon is in an error state or unreachable.
    case error

    /// Whether the daemon is in a usable state.
    public var isUsable: Bool {
        self == .running || self == .degraded
    }
}
