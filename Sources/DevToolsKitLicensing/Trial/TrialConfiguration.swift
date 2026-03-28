import Foundation

/// Configuration for the trial subsystem.
///
/// ```swift
/// let config = TrialConfiguration(durationDays: 14)
/// licensingManager.configureTrial(config)
/// ```
public struct TrialConfiguration: Sendable {
    /// Trial duration in days. Defaults to 14.
    public let durationDays: Int

    /// Whether the trial has a grace period after expiry with nag prompts
    /// before hard cutoff. Reserved for future use.
    public let graceEnabled: Bool

    /// - Parameters:
    ///   - durationDays: Number of days the trial lasts. Defaults to 14.
    ///   - graceEnabled: Whether to allow a grace period. Defaults to `false`.
    public init(durationDays: Int = 14, graceEnabled: Bool = false) {
        self.durationDays = durationDays
        self.graceEnabled = graceEnabled
    }
}
