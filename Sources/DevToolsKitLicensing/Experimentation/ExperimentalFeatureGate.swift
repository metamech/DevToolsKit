import DevToolsKit
import Foundation
import Observation

/// Evaluates experimental feature flags with prerequisite dependency resolution.
///
/// Wraps ``LicensingManager`` (which handles overrides and persistence) and adds:
/// - Prerequisite chain enforcement (e.g., feature A requires feature B)
/// - Distribution-channel-aware defaults
///
/// ```swift
/// let gate = ExperimentalFeatureGate<MyFeature>(licensingManager: manager)
/// if gate.isEnabled(.aiAssist) { ... }
/// ```
///
/// - Since: 0.9.0
@MainActor @Observable
public final class ExperimentalFeatureGate<Feature: ExperimentalFeatureProtocol> {
    private let licensingManager: LicensingManager

    /// Creates an experimental feature gate backed by the given licensing manager.
    ///
    /// - Parameter licensingManager: The licensing manager that stores overrides and flag state.
    public init(licensingManager: LicensingManager) {
        self.licensingManager = licensingManager
    }

    /// Returns whether the feature is effectively enabled.
    ///
    /// Resolution order:
    /// 1. LicensingManager (includes developer overrides and build-tier default)
    /// 2. Prerequisite chain (all prerequisites must also be enabled)
    ///
    /// - Parameter feature: The experimental feature to check.
    /// - Returns: `true` if the feature and all its prerequisites are enabled.
    public func isEnabled(_ feature: Feature) -> Bool {
        guard licensingManager.isEnabled(feature.rawValue) else { return false }
        return feature.prerequisites.allSatisfy { isEnabled($0) }
    }

    /// The underlying licensing manager.
    public var manager: LicensingManager { licensingManager }
}
