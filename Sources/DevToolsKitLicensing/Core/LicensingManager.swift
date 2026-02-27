import DevToolsKit
import Foundation
import Observation

/// Central manager for feature flags, license gating, and experimentation.
///
/// Create an instance with a key prefix and a license backend, register your flag
/// definitions, then query flag state throughout your app.
///
/// ```swift
/// let licensing = LicensingManager(keyPrefix: "myapp", backend: myBackend)
/// licensing.registerFlags([debugOverlay, newExporter])
///
/// if licensing.isEnabled("myapp.new-exporter") { ... }
/// ```
@MainActor
@Observable
public final class LicensingManager: Sendable {
    // MARK: - Configuration

    /// Prefix for all UserDefaults keys.
    public let keyPrefix: String

    /// The license validation backend.
    public let backend: any LicenseBackend

    // MARK: - Registered Flags

    /// All registered flag definitions keyed by ID.
    public private(set) var flagDefinitions: [String: FeatureFlagDefinition] = [:]

    /// Ordered list of flag IDs in registration order.
    public private(set) var flagOrder: [String] = []

    // MARK: - Enrollment

    /// Enrollment ID manager for deterministic cohort/rollout assignment.
    public let enrollment: EnrollmentID

    // MARK: - State Change Observation

    /// Monotonically increasing version counter, incremented on any state change.
    public private(set) var stateVersion: UInt64 = 0

    // MARK: - Init

    /// Create a licensing manager.
    ///
    /// - Parameters:
    ///   - keyPrefix: Prefix for all persisted keys (e.g., `"myapp"`).
    ///   - backend: The license validation backend.
    ///   - regenerationInterval: Enrollment ID regeneration interval; defaults to 90 days.
    public init(
        keyPrefix: String,
        backend: any LicenseBackend,
        regenerationInterval: TimeInterval = 90 * 24 * 60 * 60
    ) {
        self.keyPrefix = keyPrefix
        self.backend = backend
        self.enrollment = EnrollmentID(
            keyPrefix: keyPrefix, regenerationInterval: regenerationInterval)
    }

    // MARK: - Flag Registration

    /// Register a collection of feature flag definitions.
    ///
    /// Duplicate IDs are silently ignored; the first registration wins.
    ///
    /// - Parameter flags: The flag definitions to register.
    public func registerFlags(_ flags: [FeatureFlagDefinition]) {
        for flag in flags {
            guard flagDefinitions[flag.id] == nil else { continue }
            flagDefinitions[flag.id] = flag
            flagOrder.append(flag.id)
        }
    }

    /// Register a single feature flag definition.
    ///
    /// - Parameter flag: The flag definition to register.
    public func registerFlag(_ flag: FeatureFlagDefinition) {
        registerFlags([flag])
    }

    // MARK: - Flag Resolution

    /// Check whether a feature flag is enabled.
    ///
    /// Resolution order:
    /// 1. Active (non-expired) developer override → use override value
    /// 2. License tier gating → if user lacks required tier, flag is disabled
    /// 3. Experiment cohort → first cohort name is treated as enabled
    /// 4. Percentage rollout → bucket < percentage means enabled
    /// 5. Default value from definition
    ///
    /// - Parameter flagID: The flag's stable identifier.
    /// - Returns: `true` if enabled, `false` if disabled or unregistered.
    public func isEnabled(_ flagID: String) -> Bool {
        let state = flagState(for: flagID)
        FlagMetrics.recordCheck(flagID: flagID, result: state?.isEnabled ?? false)
        return state?.isEnabled ?? false
    }

    /// Get the full resolved state of a feature flag.
    ///
    /// - Parameter flagID: The flag's stable identifier.
    /// - Returns: The resolved state, or `nil` if the flag is not registered.
    public func flagState(for flagID: String) -> FeatureFlagState? {
        guard let definition = flagDefinitions[flagID] else { return nil }
        return resolveState(for: definition)
    }

    /// All resolved flag states in registration order.
    public var allFlagStates: [FeatureFlagState] {
        flagOrder.compactMap { flagState(for: $0) }
    }

    // MARK: - Entitlements

    /// Check whether a named entitlement is active.
    ///
    /// Delegates to the backend's ``LicenseBackend/activeEntitlements``.
    ///
    /// - Parameter name: The entitlement name to check.
    /// - Returns: `true` if the backend grants this entitlement.
    public func hasEntitlement(_ name: String) -> Bool {
        backend.activeEntitlements.contains(name)
    }

    // MARK: - Developer Overrides

    /// Set a developer override for a flag.
    ///
    /// - Parameters:
    ///   - enabled: The override value.
    ///   - flagID: The flag's stable identifier.
    ///   - ttl: Optional time-to-live; the override expires after this duration.
    public func setOverride(_ enabled: Bool, for flagID: String, expiresAfter ttl: Duration? = nil) {
        UserDefaults.standard.set(enabled, forKey: overrideKey(flagID))
        UserDefaults.standard.set(true, forKey: overrideExistsKey(flagID))

        if let ttl {
            let expiresAt = Date().addingTimeInterval(Double(ttl.components.seconds))
            UserDefaults.standard.set(
                expiresAt.timeIntervalSince1970, forKey: overrideExpiryKey(flagID))
        } else {
            UserDefaults.standard.removeObject(forKey: overrideExpiryKey(flagID))
        }

        FlagMetrics.recordOverride(flagID: flagID, value: enabled)
        incrementStateVersion()
    }

    /// Clear the developer override for a flag.
    ///
    /// - Parameter flagID: The flag's stable identifier.
    public func clearOverride(for flagID: String) {
        UserDefaults.standard.removeObject(forKey: overrideKey(flagID))
        UserDefaults.standard.removeObject(forKey: overrideExistsKey(flagID))
        UserDefaults.standard.removeObject(forKey: overrideExpiryKey(flagID))
        incrementStateVersion()
    }

    /// Clear all developer overrides for all registered flags.
    public func clearAllOverrides() {
        for flagID in flagOrder {
            UserDefaults.standard.removeObject(forKey: overrideKey(flagID))
            UserDefaults.standard.removeObject(forKey: overrideExistsKey(flagID))
            UserDefaults.standard.removeObject(forKey: overrideExpiryKey(flagID))
        }
        incrementStateVersion()
    }

    // MARK: - Enrollment ID Convenience

    /// The current enrollment ID value.
    public var enrollmentID: UUID { enrollment.value }

    /// When the current enrollment ID will automatically regenerate.
    public var enrollmentIDExpiresAt: Date { enrollment.expiresAt }

    /// Manually reset the enrollment ID.
    public func resetEnrollmentID() {
        enrollment.reset()
        incrementStateVersion()
    }

    // MARK: - License Actions

    /// Activate the license with the given credential, delegating to the backend.
    ///
    /// - Parameter credential: The license key or offline token.
    public func activate(with credential: LicenseCredential) async throws {
        try await backend.activate(with: credential)
        incrementStateVersion()
    }

    /// Re-validate the current license.
    public func validate() async throws {
        try await backend.validate()
        incrementStateVersion()
    }

    /// Deactivate the current license.
    public func deactivate() async throws {
        try await backend.deactivate()
        incrementStateVersion()
    }

    /// Current license status from the backend.
    public var licenseStatus: DevToolsLicenseStatus {
        backend.status
    }

    // MARK: - Async Observation

    /// An async stream that yields the flag state whenever it changes.
    ///
    /// - Parameter flagID: The flag to observe.
    /// - Returns: An async stream of state snapshots.
    public func stateChanges(for flagID: String) -> AsyncStream<FeatureFlagState> {
        AsyncStream { continuation in
            let task = Task { @MainActor [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                var lastVersion: UInt64 = 0
                while !Task.isCancelled {
                    if self.stateVersion != lastVersion {
                        lastVersion = self.stateVersion
                        if let state = self.flagState(for: flagID) {
                            continuation.yield(state)
                        }
                    }
                    try? await Task.sleep(for: .milliseconds(100))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Private Resolution

    private func resolveState(for definition: FeatureFlagDefinition) -> FeatureFlagState {
        let overrideInfo = activeOverride(for: definition.id)

        // 1. Check override
        if let override = overrideInfo {
            return FeatureFlagState(
                definition: definition,
                isEnabled: override.value,
                isOverridden: true,
                isGated: false,
                cohort: resolveCohort(for: definition),
                overrideExpiresAt: override.expiresAt
            )
        }

        // 2. Check license gating
        let isGated = !isTierSatisfied(definition.requiredTier)

        if isGated {
            return FeatureFlagState(
                definition: definition,
                isEnabled: false,
                isOverridden: false,
                isGated: true,
                cohort: nil,
                overrideExpiresAt: nil
            )
        }

        // 3. Check experiment
        if let experiment = definition.experiment {
            let eligible = experiment.targeting.allSatisfy { $0.isSatisfied() }
            if eligible {
                let cohort = CohortResolver.assignCohort(
                    enrollmentID: enrollment.value,
                    flagID: definition.id,
                    cohorts: experiment.cohorts
                )
                if let cohort {
                    FlagMetrics.recordCohortAssignment(flagID: definition.id, cohort: cohort)
                }
                // First cohort is treated as "control" (enabled), all others also enabled
                // since being in a cohort means participating
                let enabled = cohort != nil
                return FeatureFlagState(
                    definition: definition,
                    isEnabled: enabled,
                    isOverridden: false,
                    isGated: false,
                    cohort: cohort,
                    overrideExpiresAt: nil
                )
            }
        }

        // 4. Check rollout
        if let rollout = definition.rollout {
            let eligible = rollout.targeting.allSatisfy { $0.isSatisfied() }
            if eligible {
                let inRollout = CohortResolver.isInRollout(
                    enrollmentID: enrollment.value,
                    flagID: definition.id,
                    percentage: rollout.percentage
                )
                return FeatureFlagState(
                    definition: definition,
                    isEnabled: inRollout,
                    isOverridden: false,
                    isGated: false,
                    cohort: nil,
                    overrideExpiresAt: nil
                )
            }
        }

        // 5. Default
        return FeatureFlagState(
            definition: definition,
            isEnabled: definition.defaultEnabled,
            isOverridden: false,
            isGated: false,
            cohort: nil,
            overrideExpiresAt: nil
        )
    }

    private func isTierSatisfied(_ tier: LicenseTier) -> Bool {
        switch tier {
        case .free:
            return true
        case .premium:
            let status = backend.status
            return status == .active || status == .offlineValid
        case .custom(let entitlement):
            return hasEntitlement(entitlement)
        }
    }

    private func resolveCohort(for definition: FeatureFlagDefinition) -> String? {
        guard let experiment = definition.experiment else { return nil }
        return CohortResolver.assignCohort(
            enrollmentID: enrollment.value,
            flagID: definition.id,
            cohorts: experiment.cohorts
        )
    }

    private struct OverrideInfo {
        let value: Bool
        let expiresAt: Date?
    }

    private func activeOverride(for flagID: String) -> OverrideInfo? {
        guard UserDefaults.standard.bool(forKey: overrideExistsKey(flagID)) else {
            return nil
        }

        // Check expiry
        let expiryInterval = UserDefaults.standard.double(forKey: overrideExpiryKey(flagID))
        if expiryInterval > 0 {
            let expiresAt = Date(timeIntervalSince1970: expiryInterval)
            if Date() >= expiresAt {
                // Expired — clear it
                clearOverride(for: flagID)
                return nil
            }
            let value = UserDefaults.standard.bool(forKey: overrideKey(flagID))
            return OverrideInfo(value: value, expiresAt: expiresAt)
        }

        let value = UserDefaults.standard.bool(forKey: overrideKey(flagID))
        return OverrideInfo(value: value, expiresAt: nil)
    }

    // MARK: - Key Helpers

    private func key(_ suffix: String) -> String {
        "\(keyPrefix).\(suffix)"
    }

    private func overrideKey(_ flagID: String) -> String {
        key("featureFlag.override.\(flagID)")
    }

    private func overrideExistsKey(_ flagID: String) -> String {
        key("featureFlag.override.\(flagID).exists")
    }

    private func overrideExpiryKey(_ flagID: String) -> String {
        key("featureFlag.override.\(flagID).expiresAt")
    }

    private func incrementStateVersion() {
        stateVersion += 1
    }
}

// MARK: - DiagnosticProvider

extension LicensingManager: DiagnosticProvider {
    public var sectionName: String { "licensing" }

    public func collect() async -> any Codable & Sendable {
        let flags = allFlagStates.map { state in
            LicensingDiagnosticFlag(
                id: state.definition.id,
                isEnabled: state.isEnabled,
                isOverridden: state.isOverridden,
                isGated: state.isGated,
                cohort: state.cohort
            )
        }
        return LicensingDiagnosticData(
            licenseStatus: licenseStatus.rawValue,
            activeEntitlements: Array(backend.activeEntitlements).sorted(),
            registeredFlagCount: flagDefinitions.count,
            overriddenFlagCount: allFlagStates.filter(\.isOverridden).count,
            flags: flags,
            enrollmentIDGeneratedAt: enrollment.generatedAt,
            enrollmentIDExpiresAt: enrollment.expiresAt
        )
    }
}

/// Diagnostic data structure for the licensing section of diagnostic exports.
struct LicensingDiagnosticData: Codable, Sendable {
    let licenseStatus: String
    let activeEntitlements: [String]
    let registeredFlagCount: Int
    let overriddenFlagCount: Int
    let flags: [LicensingDiagnosticFlag]
    let enrollmentIDGeneratedAt: Date
    let enrollmentIDExpiresAt: Date
}

/// Diagnostic snapshot of a single flag's state.
struct LicensingDiagnosticFlag: Codable, Sendable {
    let id: String
    let isEnabled: Bool
    let isOverridden: Bool
    let isGated: Bool
    let cohort: String?
}
