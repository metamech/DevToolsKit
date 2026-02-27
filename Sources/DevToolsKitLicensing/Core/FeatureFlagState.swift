import Foundation

/// Runtime state of a feature flag, including override and experiment information.
///
/// Obtain via ``LicensingManager/flagState(for:)``.
public struct FeatureFlagState: Sendable {
    /// The flag definition this state corresponds to.
    public let definition: FeatureFlagDefinition

    /// Whether the flag is currently enabled (after all resolution logic).
    public let isEnabled: Bool

    /// Whether a developer override is active for this flag.
    public let isOverridden: Bool

    /// Whether this flag is gated by a license tier the user does not have.
    public let isGated: Bool

    /// Assigned cohort name if the flag has an experiment; `nil` otherwise.
    public let cohort: String?

    /// When the active override expires, if a TTL was set; `nil` for permanent overrides.
    public let overrideExpiresAt: Date?

    /// - Parameters:
    ///   - definition: The flag definition.
    ///   - isEnabled: Resolved enabled state.
    ///   - isOverridden: Whether an override is active.
    ///   - isGated: Whether the flag is license-gated.
    ///   - cohort: Assigned experiment cohort, if any.
    ///   - overrideExpiresAt: Override expiry date, if timed.
    public init(
        definition: FeatureFlagDefinition,
        isEnabled: Bool,
        isOverridden: Bool,
        isGated: Bool,
        cohort: String?,
        overrideExpiresAt: Date?
    ) {
        self.definition = definition
        self.isEnabled = isEnabled
        self.isOverridden = isOverridden
        self.isGated = isGated
        self.cohort = cohort
        self.overrideExpiresAt = overrideExpiresAt
    }
}
