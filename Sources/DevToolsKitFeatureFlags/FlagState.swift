import Foundation

/// The resolved runtime state of a feature flag.
///
/// Obtain via ``FeatureFlagStore/state(for:)`` or ``FeatureFlagStore/allStates``.
public struct FlagState: Sendable, Identifiable {
    /// The flag definition this state corresponds to.
    public let flag: FeatureFlag

    /// Whether the flag is currently enabled (after all resolution logic).
    public let isEnabled: Bool

    /// How the enabled value was determined.
    public let resolution: FlagResolution

    public var id: String { flag.id }

    /// Whether a developer override is active for this flag.
    public var isOverridden: Bool {
        if case .override = resolution { return true }
        return false
    }

    /// Override expiry date, if a TTL was set.
    public var overrideExpiresAt: Date? {
        if case .override(let expiresAt) = resolution { return expiresAt }
        return nil
    }

    public init(flag: FeatureFlag, isEnabled: Bool, resolution: FlagResolution) {
        self.flag = flag
        self.isEnabled = isEnabled
        self.resolution = resolution
    }
}
