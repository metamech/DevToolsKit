import Foundation

/// Describes how a feature flag's value was resolved.
///
/// Replaces the previous boolean fields (`isOverridden`, `isGated`, `cohort`) with
/// a self-describing enum that strategies can extend without adding fields.
public enum FlagResolution: Sendable {
    /// A developer override is active (persisted via ``OverrideStore``).
    case override(expiresAt: Date?)

    /// A ``FlagResolutionStrategy`` claimed resolution.
    ///
    /// - Parameters:
    ///   - name: The strategy's human-readable name (e.g., `"License Tier"`, `"Experiment"`).
    ///   - detail: Optional detail string (e.g., `"requires premium"`, `"cohort: variant-a"`).
    case strategy(name: String, detail: String?)

    /// No override or strategy claimed resolution; the flag's ``FeatureFlag/defaultEnabled`` was used.
    case defaultValue
}
