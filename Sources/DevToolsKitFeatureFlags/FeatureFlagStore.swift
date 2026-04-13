import DevToolsKit
import Foundation
import Observation

/// Central registry and resolver for feature flags.
///
/// `FeatureFlagStore` is `@Observable`, so SwiftUI views that read its properties
/// automatically re-render when flag state changes.
///
/// ```swift
/// let store = FeatureFlagStore(overrideStore: UserDefaultsOverrideStore(keyPrefix: "myapp"))
/// store.register([myFlag, anotherFlag])
///
/// if store.isEnabled("myapp.my-flag") { ... }
/// ```
@MainActor
@Observable
public final class FeatureFlagStore: Sendable {
    // MARK: - Configuration

    /// Override persistence backend.
    public let overrideStore: any OverrideStore

    // MARK: - Registered Flags

    /// All registered flag definitions keyed by ID.
    public private(set) var flagDefinitions: [String: FeatureFlag] = [:]

    /// Ordered list of flag IDs in registration order.
    public private(set) var flagOrder: [String] = []

    // MARK: - Strategies

    /// Resolution strategies evaluated in order after overrides.
    private var strategies: [any FlagResolutionStrategy] = []

    // MARK: - Metrics

    /// Optional metrics handler for flag events.
    public var metricsHandler: (any FlagMetricsHandler)?

    // MARK: - State Change Observation

    /// Monotonically increasing version counter, incremented on any state change.
    public private(set) var stateVersion: UInt64 = 0

    // MARK: - Init

    /// Create a feature flag store.
    ///
    /// - Parameters:
    ///   - overrideStore: Persistence backend for developer overrides.
    ///   - strategies: Initial resolution strategies (evaluated in order).
    public init(
        overrideStore: any OverrideStore,
        strategies: [any FlagResolutionStrategy] = []
    ) {
        self.overrideStore = overrideStore
        self.strategies = strategies
    }

    // MARK: - Flag Registration

    /// Register a collection of feature flags.
    ///
    /// Duplicate IDs are silently ignored; the first registration wins.
    public func register(_ flags: [FeatureFlag]) {
        for flag in flags {
            guard flagDefinitions[flag.id] == nil else { continue }
            flagDefinitions[flag.id] = flag
            flagOrder.append(flag.id)
        }
    }

    /// Register a single feature flag.
    public func register(_ flag: FeatureFlag) {
        register([flag])
    }

    // MARK: - Flag Resolution

    /// Check whether a feature flag is enabled.
    ///
    /// Resolution order:
    /// 1. Active (non-expired) developer override
    /// 2. Strategies in registration order (first non-nil wins)
    /// 3. Default value from definition
    ///
    /// - Parameter flagID: The flag's stable identifier.
    /// - Returns: `true` if enabled, `false` if disabled or unregistered.
    public func isEnabled(_ flagID: String) -> Bool {
        let flagState = state(for: flagID)
        let result = flagState?.isEnabled ?? false
        metricsHandler?.recordCheck(flagID: flagID, result: result)
        return result
    }

    /// Get the full resolved state of a feature flag.
    ///
    /// - Parameter flagID: The flag's stable identifier.
    /// - Returns: The resolved state, or `nil` if the flag is not registered.
    public func state(for flagID: String) -> FlagState? {
        guard let flag = flagDefinitions[flagID] else { return nil }
        return resolve(flag)
    }

    /// All resolved flag states in registration order.
    public var allStates: [FlagState] {
        flagOrder.compactMap { state(for: $0) }
    }

    // MARK: - Developer Overrides

    /// Set a developer override for a flag.
    ///
    /// - Parameters:
    ///   - enabled: The override value.
    ///   - flagID: The flag's stable identifier.
    ///   - ttl: Optional time-to-live; the override expires after this duration.
    public func setOverride(_ enabled: Bool, for flagID: String, expiresAfter ttl: Duration? = nil) {
        overrideStore.setOverride(enabled, for: flagID, expiresAfter: ttl)
        metricsHandler?.recordOverride(flagID: flagID, value: enabled)
        invalidate()
    }

    /// Clear the developer override for a flag.
    public func clearOverride(for flagID: String) {
        overrideStore.clearOverride(for: flagID)
        invalidate()
    }

    /// Clear all developer overrides for all registered flags.
    public func clearAllOverrides() {
        overrideStore.clearAll(flagIDs: flagOrder)
        invalidate()
    }

    // MARK: - Strategy Management

    /// Add a resolution strategy to the end of the chain.
    public func addStrategy(_ strategy: any FlagResolutionStrategy) {
        strategies.append(strategy)
        invalidate()
    }

    /// Remove a resolution strategy by name.
    public func removeStrategy(named name: String) {
        strategies.removeAll { $0.name == name }
        invalidate()
    }

    // MARK: - Invalidation

    /// Force re-evaluation of all flag states.
    ///
    /// Call this when external state (e.g., license status) changes and strategies
    /// may produce different results.
    public func invalidate() {
        stateVersion += 1
    }

    // MARK: - Private Resolution

    private func resolve(_ flag: FeatureFlag) -> FlagState {
        // 1. Check override
        if let override = overrideStore.override(for: flag.id) {
            return FlagState(
                flag: flag,
                isEnabled: override.enabled,
                resolution: .override(expiresAt: override.expiresAt)
            )
        }

        // 2. Check strategies in order
        for strategy in strategies {
            if let result = strategy.resolve(flag) {
                return FlagState(
                    flag: flag,
                    isEnabled: result,
                    resolution: .strategy(
                        name: strategy.name,
                        detail: strategy.detail(for: flag)
                    )
                )
            }
        }

        // 3. Default
        return FlagState(
            flag: flag,
            isEnabled: flag.defaultEnabled,
            resolution: .defaultValue
        )
    }
}

// MARK: - DiagnosticProvider

extension FeatureFlagStore: DiagnosticProvider {
    public var sectionName: String { "feature_flags" }

    public func collect() async -> any Codable & Sendable {
        let flags = allStates.map { state in
            FlagDiagnostic(
                id: state.flag.id,
                isEnabled: state.isEnabled,
                resolution: String(describing: state.resolution)
            )
        }
        return FlagStoreDiagnostic(
            registeredFlagCount: flagDefinitions.count,
            overriddenFlagCount: allStates.filter(\.isOverridden).count,
            strategyCount: strategies.count,
            strategyNames: strategies.map(\.name),
            flags: flags
        )
    }
}

struct FlagStoreDiagnostic: Codable, Sendable {
    let registeredFlagCount: Int
    let overriddenFlagCount: Int
    let strategyCount: Int
    let strategyNames: [String]
    let flags: [FlagDiagnostic]
}

struct FlagDiagnostic: Codable, Sendable {
    let id: String
    let isEnabled: Bool
    let resolution: String
}
