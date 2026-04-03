import Foundation

/// Configurable reconnection policy with exponential backoff.
///
/// ```swift
/// let policy = ReconnectionPolicy(maxAttempts: 5, baseDelay: .seconds(1), maxDelay: .seconds(30))
/// ```
///
/// - Since: 0.9.0
public struct ReconnectionPolicy: Sendable {
    /// Maximum number of reconnection attempts before giving up.
    public let maxAttempts: Int

    /// Base delay between reconnection attempts.
    public let baseDelay: Duration

    /// Maximum delay (caps exponential backoff).
    public let maxDelay: Duration

    /// Multiplier for exponential backoff.
    public let backoffMultiplier: Double

    /// Creates a reconnection policy.
    ///
    /// - Parameters:
    ///   - maxAttempts: Maximum reconnection attempts. Defaults to 3.
    ///   - baseDelay: Initial delay between attempts. Defaults to 1 second.
    ///   - maxDelay: Maximum delay cap. Defaults to 30 seconds.
    ///   - backoffMultiplier: Exponential multiplier. Defaults to 2.0.
    public init(
        maxAttempts: Int = 3,
        baseDelay: Duration = .seconds(1),
        maxDelay: Duration = .seconds(30),
        backoffMultiplier: Double = 2.0
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.backoffMultiplier = backoffMultiplier
    }

    /// Calculate the delay for the given attempt number (0-indexed).
    ///
    /// - Parameter attempt: The attempt number (0 for first retry).
    /// - Returns: The delay to wait before this attempt.
    public func delay(forAttempt attempt: Int) -> Duration {
        let baseSeconds = Double(baseDelay.components.seconds) +
            Double(baseDelay.components.attoseconds) / 1e18
        let maxSeconds = Double(maxDelay.components.seconds) +
            Double(maxDelay.components.attoseconds) / 1e18
        let multiplied = baseSeconds * pow(backoffMultiplier, Double(attempt))
        let capped = min(multiplied, maxSeconds)
        return .milliseconds(Int(capped * 1000))
    }

    /// Default policy: 3 attempts, 1s base, 30s max, 2x backoff.
    public static let `default` = ReconnectionPolicy()
}
