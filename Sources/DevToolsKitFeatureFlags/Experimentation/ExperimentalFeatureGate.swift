import DevToolsKit
import Foundation
import Observation

/// Evaluates experimental feature flags with prerequisite dependency resolution.
///
/// Wraps ``FeatureFlagStore`` and adds:
/// - Prerequisite chain enforcement (e.g., feature A requires feature B)
/// - Distribution-channel-aware defaults
@MainActor @Observable
public final class ExperimentalFeatureGate<Feature: ExperimentalFeatureProtocol> {
    private let store: FeatureFlagStore

    /// Creates an experimental feature gate backed by the given flag store.
    public init(store: FeatureFlagStore) {
        self.store = store
    }

    /// Returns whether the feature is effectively enabled.
    ///
    /// Resolution order:
    /// 1. FeatureFlagStore (includes developer overrides, strategies, and defaults)
    /// 2. Prerequisite chain (all prerequisites must also be enabled)
    public func isEnabled(_ feature: Feature) -> Bool {
        guard store.isEnabled(feature.rawValue) else { return false }
        return feature.prerequisites.allSatisfy { isEnabled($0) }
    }

    /// The underlying flag store.
    public var flagStore: FeatureFlagStore { store }
}
