import SwiftUI

/// Environment key for accessing an experimental feature gate.
///
/// - Since: 0.9.0
public struct ExperimentalFeatureGateEnvironmentKey<Feature: ExperimentalFeatureProtocol>: @preconcurrency EnvironmentKey {
    @MainActor public static var defaultValue: ExperimentalFeatureGate<Feature>? { nil }
}

/// View modifier that conditionally includes content based on an experimental feature flag.
///
/// When the feature is disabled, the view is removed from the hierarchy entirely.
/// Use at entry points (menus, settings sections, sidebar badges) — not inside
/// feature implementation code.
///
/// ```swift
/// MyView()
///     .featureGated(.aiAssist, keyPath: \EnvironmentValues.myAppGate)
/// ```
///
/// - Since: 0.9.0
public struct FeatureGateModifier<Feature: ExperimentalFeatureProtocol>: ViewModifier {
    @Environment private var gate: ExperimentalFeatureGate<Feature>?
    private let feature: Feature

    /// Creates a feature gate modifier.
    ///
    /// - Parameters:
    ///   - feature: The feature to gate on.
    ///   - keyPath: The environment key path to the feature gate.
    public init(
        feature: Feature,
        keyPath: KeyPath<EnvironmentValues, ExperimentalFeatureGate<Feature>?>
    ) {
        self.feature = feature
        self._gate = Environment(keyPath)
    }

    public func body(content: Content) -> some View {
        if gate?.isEnabled(feature) == true {
            content
        }
    }
}

extension View {
    /// Gates this view behind an experimental feature flag.
    ///
    /// When the feature is disabled, the view is removed from the hierarchy.
    /// Use at entry points only (menus, settings sections, sidebar badges).
    ///
    /// - Parameters:
    ///   - feature: The experimental feature to check.
    ///   - keyPath: The environment key path to the feature gate.
    /// - Returns: A view that is only visible when the feature is enabled.
    public func featureGated<Feature: ExperimentalFeatureProtocol>(
        _ feature: Feature,
        keyPath: KeyPath<EnvironmentValues, ExperimentalFeatureGate<Feature>?>
    ) -> some View {
        modifier(FeatureGateModifier(feature: feature, keyPath: keyPath))
    }
}
