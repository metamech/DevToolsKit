import SwiftUI
import WelcomeKit

public extension View {
    /// One-liner integration for the complete licensing flow.
    ///
    /// Combines WelcomeKit flow presentation (blocking overlays for licensing gates)
    /// with a non-blocking trial banner. Handles all licensing states automatically.
    ///
    /// ```swift
    /// ContentView()
    ///     .licensingFlow(
    ///         offering: .myOffering,
    ///         manager: licensingManager,
    ///         devSimulationEnabled: AppEnvironment.isLicenseTestingEnabled
    ///     )
    /// ```
    func licensingFlow(
        offering: LicensingOffering,
        manager: LicensingManager,
        devSimulationEnabled: Bool = false
    ) -> some View {
        let resolver = LicensingFlowResolver(
            offering: offering,
            manager: manager,
            devSimulationEnabled: devSimulationEnabled
        )

        return self
            .welcomeFlow(resolver.asWelcomeFlow())
            .trialBanner(manager: manager) {
                // TODO: Show purchase sheet when "Buy Now" tapped in trial banner
            }
    }
}
