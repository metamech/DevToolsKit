import DevToolsKitFeatureFlags
import Foundation

/// A ``FlagResolutionStrategy`` that gates feature flags by license tier.
///
/// Flags not in the `tiers` map are deferred (return `nil`).
/// Flags whose tier IS satisfied are also deferred (the flag proceeds to the next strategy or default).
/// Flags whose tier is NOT satisfied are blocked (return `false`).
///
/// ```swift
/// let strategy = LicenseTierStrategy(
///     licensing: manager,
///     tiers: ["myapp.premium-feature": .premium]
/// )
/// flagStore.addStrategy(strategy)
/// ```
@MainActor
public final class LicenseTierStrategy: FlagResolutionStrategy, @unchecked Sendable {
    private let licensing: LicensingManager
    private let tiers: [String: LicenseTier]

    public let name = "License Tier"

    /// - Parameters:
    ///   - licensing: The licensing manager to check tier satisfaction against.
    ///   - tiers: Map of flagID -> required license tier.
    public init(licensing: LicensingManager, tiers: [String: LicenseTier]) {
        self.licensing = licensing
        self.tiers = tiers
    }

    public func resolve(_ flag: FeatureFlag) -> Bool? {
        guard let requiredTier = tiers[flag.id] else { return nil }
        // If tier IS satisfied, defer (nil) -- let next strategy or default decide
        // If tier is NOT satisfied, block (false)
        return licensing.isTierSatisfied(requiredTier) ? nil : false
    }

    public func detail(for flag: FeatureFlag) -> String? {
        guard let tier = tiers[flag.id] else { return nil }
        switch tier {
        case .free: return nil
        case .premium: return "requires premium"
        case .custom(let entitlement): return "requires \(entitlement)"
        }
    }
}
