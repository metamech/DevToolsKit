import Foundation

/// A feature flag definition — the static metadata about a flag.
///
/// Unlike the previous `FeatureFlagDefinition`, this type has no licensing concepts.
/// Resolution behaviors (tier gating, experiments, rollouts) are attached externally
/// via ``FlagResolutionStrategy`` conformances.
public struct FeatureFlag: Sendable, Hashable, Identifiable {
    /// Stable identifier in reverse-domain style (e.g., `"myapp.new-feature"`).
    public let id: String

    /// Human-readable name shown in the Feature Flags panel.
    public let name: String

    /// Description of what this flag controls.
    public let description: String

    /// Category for grouping in the panel UI (e.g., `"Debug"`, `"Experimental"`).
    public let category: String

    /// Default value when no override or strategy claims resolution.
    public let defaultEnabled: Bool

    public init(
        id: String,
        name: String,
        description: String,
        category: String = "General",
        defaultEnabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.defaultEnabled = defaultEnabled
    }
}
