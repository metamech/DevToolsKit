import Foundation

/// Persists developer overrides for feature flags.
///
/// The default ``UserDefaultsOverrideStore`` uses the same key scheme as the
/// previous `LicensingManager`, so existing overrides survive migration.
public protocol OverrideStore: Sendable {
    /// Read the current override for a flag, if one exists and hasn't expired.
    @MainActor func override(for flagID: String) -> OverrideValue?

    /// Set an override for a flag.
    @MainActor func setOverride(_ enabled: Bool, for flagID: String, expiresAfter ttl: Duration?)

    /// Clear the override for a flag.
    @MainActor func clearOverride(for flagID: String)

    /// Clear all overrides.
    @MainActor func clearAll(flagIDs: [String])
}

/// A persisted override value with optional expiry.
public struct OverrideValue: Sendable {
    /// The override's boolean value.
    public let enabled: Bool

    /// When the override expires, or `nil` for permanent overrides.
    public let expiresAt: Date?

    public init(enabled: Bool, expiresAt: Date? = nil) {
        self.enabled = enabled
        self.expiresAt = expiresAt
    }
}

/// Default ``OverrideStore`` backed by `UserDefaults`.
///
/// Uses the key scheme `{keyPrefix}.featureFlag.override.{flagID}` — identical
/// to the previous `LicensingManager` so existing overrides survive migration.
@MainActor
public final class UserDefaultsOverrideStore: OverrideStore {
    private nonisolated(unsafe) let keyPrefix: String
    private nonisolated(unsafe) let defaults: UserDefaults

    public nonisolated init(keyPrefix: String, defaults: UserDefaults = .standard) {
        self.keyPrefix = keyPrefix
        self.defaults = defaults
    }

    public func override(for flagID: String) -> OverrideValue? {
        guard defaults.bool(forKey: existsKey(flagID)) else { return nil }

        let expiryInterval = defaults.double(forKey: expiryKey(flagID))
        if expiryInterval > 0 {
            let expiresAt = Date(timeIntervalSince1970: expiryInterval)
            if Date() >= expiresAt {
                clearOverride(for: flagID)
                return nil
            }
            return OverrideValue(enabled: defaults.bool(forKey: valueKey(flagID)), expiresAt: expiresAt)
        }

        return OverrideValue(enabled: defaults.bool(forKey: valueKey(flagID)))
    }

    public func setOverride(_ enabled: Bool, for flagID: String, expiresAfter ttl: Duration?) {
        defaults.set(enabled, forKey: valueKey(flagID))
        defaults.set(true, forKey: existsKey(flagID))

        if let ttl {
            let expiresAt = Date().addingTimeInterval(Double(ttl.components.seconds))
            defaults.set(expiresAt.timeIntervalSince1970, forKey: expiryKey(flagID))
        } else {
            defaults.removeObject(forKey: expiryKey(flagID))
        }
    }

    public func clearOverride(for flagID: String) {
        defaults.removeObject(forKey: valueKey(flagID))
        defaults.removeObject(forKey: existsKey(flagID))
        defaults.removeObject(forKey: expiryKey(flagID))
    }

    public func clearAll(flagIDs: [String]) {
        for flagID in flagIDs {
            clearOverride(for: flagID)
        }
    }

    // Same key scheme as legacy LicensingManager
    private func valueKey(_ flagID: String) -> String {
        "\(keyPrefix).featureFlag.override.\(flagID)"
    }

    private func existsKey(_ flagID: String) -> String {
        "\(keyPrefix).featureFlag.override.\(flagID).exists"
    }

    private func expiryKey(_ flagID: String) -> String {
        "\(keyPrefix).featureFlag.override.\(flagID).expiresAt"
    }
}
