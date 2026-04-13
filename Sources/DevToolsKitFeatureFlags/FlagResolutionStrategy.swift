import Foundation

/// A pluggable strategy for resolving feature flag values.
///
/// Strategies are evaluated in order by ``FeatureFlagStore``. The first strategy
/// to return a non-nil value claims resolution. Return `nil` to defer to the
/// next strategy in the chain.
///
/// Resolution order in `FeatureFlagStore`:
/// 1. Developer override (built-in, always first)
/// 2. Strategies in registration order (first non-nil wins)
/// 3. ``FeatureFlag/defaultEnabled``
public protocol FlagResolutionStrategy: Sendable {
    /// Attempt to resolve the flag's enabled state.
    ///
    /// - Parameter flag: The feature flag to resolve.
    /// - Returns: `true` or `false` to claim resolution, or `nil` to defer.
    @MainActor func resolve(_ flag: FeatureFlag) -> Bool?

    /// Human-readable name for the panel UI (e.g., `"License Tier"`, `"Experiment"`).
    var name: String { get }

    /// Detail string shown in the panel when this strategy claims resolution.
    ///
    /// - Parameter flag: The feature flag to describe.
    /// - Returns: Optional detail (e.g., `"requires premium"`, `"cohort: variant-a"`).
    @MainActor func detail(for flag: FeatureFlag) -> String?
}
