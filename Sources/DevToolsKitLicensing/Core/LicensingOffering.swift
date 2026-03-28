import Foundation

/// A RevenueCat-inspired offering that describes an app's licensing presentation.
///
/// Host apps create an offering to configure the licensing flow views with their
/// branding, features, pricing tiers, and call-to-action text.
///
/// ```swift
/// let offering = LicensingOffering(
///     appName: "My App",
///     appIconName: "app.badge",
///     tagline: "The best app ever",
///     features: [
///         .init(id: "feature1", icon: "star", title: "Feature 1", description: "Does things"),
///     ],
///     pricingTiers: [
///         .init(id: "personal", name: "Personal", price: "$29", period: "one-time", isPopular: true),
///     ],
///     purchaseURL: URL(string: "https://myapp.com/purchase")!,
///     trialDurationDays: 14
/// )
/// ```
public struct LicensingOffering: Sendable {
    /// App display name shown in licensing flow headers.
    public let appName: String

    /// SF Symbol name for the app icon. Used as fallback; apps can override
    /// with a custom `Image` in the page factories.
    public let appIconName: String

    /// Short tagline shown below the app name on welcome screens.
    public let tagline: String

    /// Features to highlight in the licensing flow.
    public let features: [Feature]

    /// Available pricing tiers.
    public let pricingTiers: [PricingTier]

    /// Default purchase URL opened when user taps "Purchase".
    public let purchaseURL: URL?

    /// Custom purchase handler called with the selected tier.
    /// If both `purchaseURL` and `purchaseHandler` are provided,
    /// the handler takes precedence.
    public let purchaseHandler: (@Sendable (PricingTier) async throws -> Void)?

    /// Call-to-action text customization.
    public let ctaText: CTAText

    /// Trial duration in days, shown in UI copy. Defaults to 14.
    public let trialDurationDays: Int

    public init(
        appName: String,
        appIconName: String,
        tagline: String,
        features: [Feature],
        pricingTiers: [PricingTier],
        purchaseURL: URL? = nil,
        purchaseHandler: (@Sendable (PricingTier) async throws -> Void)? = nil,
        ctaText: CTAText = .default,
        trialDurationDays: Int = 14
    ) {
        self.appName = appName
        self.appIconName = appIconName
        self.tagline = tagline
        self.features = features
        self.pricingTiers = pricingTiers
        self.purchaseURL = purchaseURL
        self.purchaseHandler = purchaseHandler
        self.ctaText = ctaText
        self.trialDurationDays = trialDurationDays
    }
}

// MARK: - Feature

extension LicensingOffering {
    /// A feature to highlight in the licensing flow.
    public struct Feature: Sendable, Identifiable {
        public let id: String

        /// SF Symbol name for the feature icon.
        public let icon: String

        /// Feature title (e.g., "Unlimited Terminals").
        public let title: String

        /// Short description of the feature.
        public let description: String

        /// Whether this feature requires a paid license (shown with lock icon in expired views).
        public let isPremium: Bool

        public init(
            id: String,
            icon: String,
            title: String,
            description: String,
            isPremium: Bool = false
        ) {
            self.id = id
            self.icon = icon
            self.title = title
            self.description = description
            self.isPremium = isPremium
        }
    }
}

// MARK: - PricingTier

extension LicensingOffering {
    /// A pricing tier shown on the purchase screen.
    public struct PricingTier: Sendable, Identifiable {
        public let id: String

        /// Tier name (e.g., "Personal", "Team").
        public let name: String

        /// Formatted price string (e.g., "$29", "$12/mo").
        public let price: String

        /// Payment period (e.g., "one-time", "per year"). Nil for one-time purchases.
        public let period: String?

        /// Feature bullet points included in this tier.
        public let includedFeatures: [String]

        /// Whether this tier should be visually highlighted (e.g., "Popular" badge).
        public let isPopular: Bool

        /// Tier-specific purchase URL, overriding the offering's default.
        public let purchaseURL: URL?

        public init(
            id: String,
            name: String,
            price: String,
            period: String? = nil,
            includedFeatures: [String] = [],
            isPopular: Bool = false,
            purchaseURL: URL? = nil
        ) {
            self.id = id
            self.name = name
            self.price = price
            self.period = period
            self.includedFeatures = includedFeatures
            self.isPopular = isPopular
            self.purchaseURL = purchaseURL
        }
    }
}

// MARK: - CTAText

extension LicensingOffering {
    /// Customizable call-to-action strings for the licensing flow.
    public struct CTAText: Sendable {
        public let startTrial: String
        public let purchase: String
        public let enterKey: String
        public let renew: String
        public let getStarted: String

        public init(
            startTrial: String = "Start Free Trial",
            purchase: String = "Purchase",
            enterKey: String = "Enter License Key",
            renew: String = "Renew License",
            getStarted: String = "Get Started"
        ) {
            self.startTrial = startTrial
            self.purchase = purchase
            self.enterKey = enterKey
            self.renew = renew
            self.getStarted = getStarted
        }

        public static let `default` = CTAText()
    }
}
