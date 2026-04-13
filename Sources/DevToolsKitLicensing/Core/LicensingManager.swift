@_exported import DevToolsKitFeatureFlags
import DevToolsKit
import Foundation
import Observation

/// Central manager for license lifecycle — activation, validation, trial, and entitlements.
///
/// Feature flag APIs have moved to ``FeatureFlagStore`` in `DevToolsKitFeatureFlags`.
/// Use ``LicenseTierStrategy`` to connect license gating to the flag store.
///
/// ```swift
/// let licensing = LicensingManager(keyPrefix: "myapp", backend: myBackend)
/// try await licensing.activate(with: .licenseKey("..."))
/// ```
@MainActor
@Observable
public final class LicensingManager: Sendable {
    // MARK: - Configuration

    /// Prefix for all UserDefaults keys.
    public let keyPrefix: String

    /// The license validation backend.
    public let backend: any LicenseBackend

    // MARK: - Trial

    /// Trial manager, if configured via ``configureTrial(_:)``.
    public private(set) var trial: TrialManager?

    // MARK: - Init

    /// Create a licensing manager.
    ///
    /// - Parameters:
    ///   - keyPrefix: Prefix for all persisted keys (e.g., `"myapp"`).
    ///   - backend: The license validation backend.
    public init(
        keyPrefix: String,
        backend: any LicenseBackend
    ) {
        self.keyPrefix = keyPrefix
        self.backend = backend
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

    // MARK: - License Tier

    /// Check whether the current license state satisfies a tier requirement.
    ///
    /// - Parameter tier: The license tier to check.
    /// - Returns: `true` if the user's current license/trial state meets or exceeds the tier.
    public func isTierSatisfied(_ tier: LicenseTier) -> Bool {
        switch tier {
        case .free:
            return true
        case .premium:
            let status = backend.status
            if status == .active || status == .offlineValid { return true }
            // Active trial grants premium access
            if let trial, trial.state == .active { return true }
            return false
        case .custom(let entitlement):
            return hasEntitlement(entitlement)
        }
    }

    // MARK: - License Actions

    /// Activate the license with the given credential, delegating to the backend.
    ///
    /// - Parameter credential: The license key or offline token.
    public func activate(with credential: LicenseCredential) async throws {
        try await backend.activate(with: credential)
    }

    /// Re-validate the current license.
    public func validate() async throws {
        try await backend.validate()
    }

    /// Deactivate the current license.
    public func deactivate() async throws {
        try await backend.deactivate()
    }

    /// Current license status from the backend.
    public var licenseStatus: DevToolsLicenseStatus {
        backend.status
    }

    // MARK: - Trial Configuration

    /// Configure the trial subsystem.
    ///
    /// Call this once during app initialization, before calling `startTrialIfNeeded()`.
    ///
    /// - Parameter config: Trial duration and behavior settings.
    public func configureTrial(_ config: TrialConfiguration = .init()) {
        self.trial = TrialManager(keyPrefix: keyPrefix, configuration: config)
    }

    // MARK: - Effective License State

    /// The composite licensing state, combining backend status and trial state.
    ///
    /// This is the primary property that UI flows should use to determine which screen to show.
    public var effectiveState: EffectiveLicenseState {
        let status = backend.status

        // Licensed: backend reports active
        if status == .active || status == .offlineValid {
            return .licensed
        }

        // No trial configured: fall through to backend-only states
        guard let trial else {
            if status == .expired {
                return .expired
            }
            return .unlicensed
        }

        // Trial active
        if trial.state == .active {
            return .trial(daysRemaining: trial.daysRemaining)
        }

        // Was licensed but expired
        if trial.wasEverLicensed || status == .expired {
            return .expired
        }

        // Trial expired, never licensed
        if trial.state == .expired {
            return .trialExpired
        }

        // First run, trial not started
        return .unlicensed
    }
}

// MARK: - DiagnosticProvider

extension LicensingManager: DiagnosticProvider {
    public var sectionName: String { "licensing" }

    public func collect() async -> any Codable & Sendable {
        LicensingDiagnosticData(
            licenseStatus: licenseStatus.rawValue,
            effectiveState: String(describing: effectiveState),
            activeEntitlements: Array(backend.activeEntitlements).sorted(),
            trialState: trial?.state.rawValue,
            trialDaysRemaining: trial?.daysRemaining,
            trialStartDate: trial?.firstLaunchDate,
            trialExpiryDate: trial?.trialExpiryDate
        )
    }
}

/// The composite licensing state that UI flows use to determine which screen to show.
///
/// Combines backend license status with trial state into a single actionable enum.
public enum EffectiveLicenseState: Sendable, Equatable {
    /// Backend reports an active or offline-valid license.
    case licensed

    /// Trial is currently active with the given number of days remaining.
    case trial(daysRemaining: Int)

    /// Trial period has elapsed and the user never purchased a license.
    case trialExpired

    /// The user was previously licensed but their license has expired.
    case expired

    /// No trial started (first launch) or no trial configured and no active license.
    case unlicensed
}

/// Diagnostic data structure for the licensing section of diagnostic exports.
struct LicensingDiagnosticData: Codable, Sendable {
    let licenseStatus: String
    let effectiveState: String
    let activeEntitlements: [String]
    let trialState: String?
    let trialDaysRemaining: Int?
    let trialStartDate: Date?
    let trialExpiryDate: Date?
}
