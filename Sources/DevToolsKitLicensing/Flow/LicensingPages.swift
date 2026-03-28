import SwiftUI
import WelcomeKit

/// Factory methods that produce `WelcomePage` instances from a `LicensingOffering`.
///
/// These pages plug into WelcomeKit's flow system. Use them with ``LicensingFlowResolver``
/// or compose custom flows manually:
///
/// ```swift
/// let screen = WelcomeScreen(
///     id: "my-welcome",
///     pages: [
///         LicensingPages.hero(from: offering),
///         LicensingPages.features(from: offering),
///         LicensingPages.trialStart(offering: offering, manager: licensing),
///     ],
///     presentationMode: .blocking
/// )
/// ```
public enum LicensingPages {

    /// Hero page with the app icon, name, and tagline.
    public static func hero(from offering: LicensingOffering) -> WelcomePage {
        .hero(
            icon: .systemName(offering.appIconName),
            title: offering.appName,
            subtitle: offering.tagline
        )
    }

    /// Feature list page from the offering's feature definitions.
    public static func features(from offering: LicensingOffering) -> WelcomePage {
        .featureList(
            title: "Built for You",
            features: offering.features.map { feature in
                WelcomeFeature(
                    icon: .systemName(feature.icon),
                    title: feature.title,
                    description: feature.description
                )
            }
        )
    }

    /// "Start Free Trial" action page.
    ///
    /// The primary action starts the trial via `manager.trial?.startTrialIfNeeded()`
    /// and marks the welcome as seen. The secondary action navigates to license key entry.
    @MainActor
    public static func trialStart(
        offering: LicensingOffering,
        manager: LicensingManager
    ) -> WelcomePage {
        let trialDays = offering.trialDurationDays
        let ctaText = offering.ctaText

        return .action(
            icon: .systemName(offering.appIconName),
            title: "Try \(offering.appName) Free",
            body: "Start your \(trialDays)-day free trial. No credit card required. All features unlocked.",
            primaryAction: WelcomeAction(
                title: ctaText.startTrial,
                style: .primary,
                dismissesFlow: true
            ) { @MainActor in
                manager.trial?.startTrialIfNeeded()
                manager.trial?.hasSeenWelcome = true
            },
            secondaryAction: WelcomeAction(
                title: ctaText.enterKey,
                style: .secondary,
                dismissesFlow: false
            ) {
                // Navigator-based: custom pages can use navigator.goToPage()
                // For now this is a no-op; the license key entry is a separate page
            }
        )
    }

    /// Pricing tiers + purchase CTA page (custom page).
    @MainActor
    public static func purchase(
        offering: LicensingOffering,
        manager: LicensingManager,
        devSimulationEnabled: Bool = false
    ) -> WelcomePage {
        nonisolated(unsafe) let content = AnyView(
            PurchasePageContent(
                offering: offering,
                manager: manager,
                devSimulationEnabled: devSimulationEnabled
            )
        )
        return .custom { content }
    }

    /// License key entry page (custom page).
    @MainActor
    public static func licenseKeyEntry(
        manager: LicensingManager
    ) -> WelcomePage {
        nonisolated(unsafe) let content = AnyView(
            LicenseKeyEntryView(manager: manager)
        )
        return .custom { content }
    }

    /// "Trial expired" notice page.
    public static func trialExpiredNotice(
        offering: LicensingOffering
    ) -> WelcomePage {
        .action(
            icon: .systemName("clock.badge.xmark"),
            title: "Your Trial Has Ended",
            body: "Your \(offering.trialDurationDays)-day free trial of \(offering.appName) has expired. Purchase a license to continue using all features.",
            primaryAction: WelcomeAction(
                title: offering.ctaText.purchase,
                style: .primary,
                dismissesFlow: false
            ) {
                // Navigate to purchase page via navigator
            },
            secondaryAction: WelcomeAction(
                title: offering.ctaText.enterKey,
                style: .secondary,
                dismissesFlow: false
            ) {
                // Navigate to license key entry via navigator
            }
        )
    }

    /// "License expired" notice page for previously licensed users.
    public static func licenseExpiredNotice(
        offering: LicensingOffering,
        expiryDate: Date? = nil
    ) -> WelcomePage {
        let dateStr: String
        if let date = expiryDate {
            dateStr = " on \(date.formatted(date: .abbreviated, time: .omitted))"
        } else {
            dateStr = ""
        }

        return .action(
            icon: .systemName("exclamationmark.triangle"),
            title: "Your License Has Expired",
            body: "Your \(offering.appName) license expired\(dateStr). Renew to continue using all features.",
            primaryAction: WelcomeAction(
                title: offering.ctaText.renew,
                style: .primary,
                dismissesFlow: false
            ) {},
            secondaryAction: WelcomeAction(
                title: offering.ctaText.enterKey,
                style: .secondary,
                dismissesFlow: false
            ) {}
        )
    }

    /// Purchase success confirmation page.
    public static func purchaseSuccess(
        offering: LicensingOffering
    ) -> WelcomePage {
        .action(
            icon: .systemName("checkmark.seal.fill"),
            title: "Welcome to \(offering.appName)!",
            body: "Your license is active. All features are now unlocked.",
            primaryAction: WelcomeAction(
                title: offering.ctaText.getStarted,
                style: .primary,
                dismissesFlow: true
            ) {}
        )
    }
}
