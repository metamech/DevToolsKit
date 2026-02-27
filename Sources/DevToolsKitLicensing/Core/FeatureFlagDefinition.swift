import Foundation

/// Defines a feature flag with its metadata, default value, license gating, and experiment config.
///
/// Create definitions at app startup and register them with ``LicensingManager/registerFlags(_:)``.
///
/// ```swift
/// let flag = FeatureFlagDefinition(
///     id: "myapp.new-feature",
///     name: "New Feature",
///     description: "Enables the new feature",
///     category: "Experimental",
///     defaultEnabled: false,
///     requiredTier: .premium
/// )
/// ```
public struct FeatureFlagDefinition: Sendable, Hashable, Identifiable {
    /// Stable identifier in reverse-domain style (e.g., `"myapp.new-feature"`).
    public let id: String

    /// Human-readable name shown in the Feature Flags panel.
    public let name: String

    /// Description of what this flag controls.
    public let description: String

    /// Category for grouping in the panel UI (e.g., `"Debug"`, `"Experimental"`).
    public let category: String

    /// Default value when no override, rollout, or experiment applies.
    public let defaultEnabled: Bool

    /// Minimum license tier required for this flag to be enabled.
    public let requiredTier: LicenseTier

    /// Optional percentage rollout configuration.
    public let rollout: RolloutDefinition?

    /// Optional multi-cohort experiment configuration.
    public let experiment: CohortDefinition?

    /// - Parameters:
    ///   - id: Stable identifier in reverse-domain style.
    ///   - name: Human-readable name.
    ///   - description: Description of the flag's purpose.
    ///   - category: Category for panel grouping.
    ///   - defaultEnabled: Default value; defaults to `false`.
    ///   - requiredTier: License tier required; defaults to `.free`.
    ///   - rollout: Optional rollout config for gradual enablement.
    ///   - experiment: Optional cohort experiment config.
    public init(
        id: String,
        name: String,
        description: String,
        category: String,
        defaultEnabled: Bool = false,
        requiredTier: LicenseTier = .free,
        rollout: RolloutDefinition? = nil,
        experiment: CohortDefinition? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.defaultEnabled = defaultEnabled
        self.requiredTier = requiredTier
        self.rollout = rollout
        self.experiment = experiment
    }
}
