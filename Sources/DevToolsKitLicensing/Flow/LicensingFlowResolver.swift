import Foundation
import WelcomeKit

/// Resolves which WelcomeScreen to show based on the current licensing state.
///
/// Use with WelcomeKit's `.welcomeFlow()` modifier for automatic state-driven presentation:
///
/// ```swift
/// let resolver = LicensingFlowResolver(
///     offering: myOffering,
///     manager: licensingManager,
///     devSimulationEnabled: AppEnvironment.isLicenseTestingEnabled
/// )
///
/// ContentView()
///     .welcomeFlow(resolver.asWelcomeFlow())
/// ```
@MainActor
public struct LicensingFlowResolver: Sendable {
    public let offering: LicensingOffering
    public let manager: LicensingManager
    public let devSimulationEnabled: Bool

    public init(
        offering: LicensingOffering,
        manager: LicensingManager,
        devSimulationEnabled: Bool = false
    ) {
        self.offering = offering
        self.manager = manager
        self.devSimulationEnabled = devSimulationEnabled
    }

    /// Returns the WelcomeScreen to show, or `nil` if the app should run normally.
    ///
    /// Resolution based on ``LicensingManager/effectiveState``:
    /// - `.licensed` → nil (no flow)
    /// - `.trial` → nil (no blocking flow; trial banner shown separately)
    /// - `.unlicensed` → Welcome + Features + Trial Start
    /// - `.trialExpired` → Trial Expired + Purchase + Key Entry
    /// - `.expired` → License Expired + Purchase + Key Entry
    public func resolve() -> WelcomeScreen? {
        switch manager.effectiveState {
        case .licensed:
            return nil

        case .trial:
            return nil

        case .unlicensed:
            return WelcomeScreen(
                id: "licensing-welcome",
                pages: [
                    LicensingPages.hero(from: offering),
                    LicensingPages.features(from: offering),
                    LicensingPages.trialStart(offering: offering, manager: manager),
                ],
                presentationMode: .blocking
            )

        case .trialExpired:
            return WelcomeScreen(
                id: "licensing-trial-expired",
                pages: [
                    LicensingPages.trialExpiredNotice(offering: offering),
                    LicensingPages.purchase(
                        offering: offering, manager: manager,
                        devSimulationEnabled: devSimulationEnabled),
                    LicensingPages.licenseKeyEntry(manager: manager),
                ],
                presentationMode: .blocking
            )

        case .expired:
            return WelcomeScreen(
                id: "licensing-expired",
                pages: [
                    LicensingPages.licenseExpiredNotice(offering: offering),
                    LicensingPages.purchase(
                        offering: offering, manager: manager,
                        devSimulationEnabled: devSimulationEnabled),
                    LicensingPages.licenseKeyEntry(manager: manager),
                ],
                presentationMode: .blocking
            )
        }
    }

    /// Returns a `WelcomeFlow` for use with the `.welcomeFlow()` view modifier.
    public nonisolated func asWelcomeFlow() -> WelcomeFlow {
        WelcomeFlow(id: "licensing") { [self] in
            MainActor.assumeIsolated { self.resolve() }
        }
    }
}
