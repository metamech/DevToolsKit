import Foundation

/// Protocol for health check implementations.
///
/// Conforming types encapsulate the mechanism used to verify a daemon is alive
/// and healthy (e.g., HTTP endpoint, XPC ping, Unix socket).
///
/// ```swift
/// struct HTTPHealthCheck: HealthCheckStrategy {
///     let url: URL
///     func check() async -> HealthCheckResult {
///         // GET /health and inspect response
///     }
/// }
/// ```
///
/// - Since: 0.9.0
public protocol HealthCheckStrategy: Sendable {
    /// Perform a health check and return the result.
    func check() async -> HealthCheckResult
}

/// The result of a single health check.
///
/// - Since: 0.9.0
public struct HealthCheckResult: Sendable, Equatable {
    /// The determined health status.
    public let status: DaemonHealthStatus

    /// Optional human-readable message describing the check result.
    public let message: String?

    /// When the check was performed.
    public let timestamp: Date

    /// Creates a health check result.
    public init(status: DaemonHealthStatus, message: String? = nil, timestamp: Date = Date()) {
        self.status = status
        self.message = message
        self.timestamp = timestamp
    }

    /// Convenience for a healthy result.
    public static func healthy(message: String? = nil) -> HealthCheckResult {
        HealthCheckResult(status: .running, message: message)
    }

    /// Convenience for an error result.
    public static func error(_ message: String) -> HealthCheckResult {
        HealthCheckResult(status: .error, message: message)
    }

    /// Convenience for a degraded result.
    public static func degraded(_ message: String) -> HealthCheckResult {
        HealthCheckResult(status: .degraded, message: message)
    }
}
