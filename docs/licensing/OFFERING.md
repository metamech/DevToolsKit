# LicensingOffering

A RevenueCat-inspired data model for configuring licensing flow views.

## Structure

```swift
LicensingOffering
  |- appName: String
  |- appIconName: String          // SF Symbol name
  |- tagline: String
  |- features: [Feature]
  |- pricingTiers: [PricingTier]
  |- purchaseURL: URL?
  |- purchaseHandler: ((PricingTier) async throws -> Void)?
  |- ctaText: CTAText
  |- trialDurationDays: Int       // Default: 14
```

## Example

```swift
extension LicensingOffering {
    static let myApp = LicensingOffering(
        appName: "My App",
        appIconName: "app.badge",
        tagline: "The best app for developers",
        features: [
            Feature(id: "editing", icon: "pencil", title: "Smart Editing",
                    description: "AI-powered code editing"),
            Feature(id: "sync", icon: "arrow.triangle.2.circlepath", title: "Cloud Sync",
                    description: "Sync across devices", isPremium: true),
        ],
        pricingTiers: [
            PricingTier(
                id: "personal", name: "Personal", price: "$29",
                period: "one-time",
                includedFeatures: ["All features", "1 year of updates"],
                isPopular: true,
                purchaseURL: URL(string: "https://myapp.com/buy")
            ),
        ],
        purchaseURL: URL(string: "https://myapp.com/buy"),
        trialDurationDays: 14
    )
}
```

## Feature

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `icon` | String | SF Symbol name |
| `title` | String | Display name |
| `description` | String | Short description |
| `isPremium` | Bool | Shows lock icon in expired views (default: false) |

## PricingTier

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier |
| `name` | String | Tier name (e.g., "Personal") |
| `price` | String | Formatted price (e.g., "$29") |
| `period` | String? | Payment period (nil for one-time) |
| `includedFeatures` | [String] | Bullet points |
| `isPopular` | Bool | Shows "Popular" badge |
| `purchaseURL` | URL? | Overrides offering-level URL |

## CTAText

Customizable button labels with sensible defaults:

| Property | Default |
|----------|---------|
| `startTrial` | "Start Free Trial" |
| `purchase` | "Purchase" |
| `enterKey` | "Enter License Key" |
| `renew` | "Renew License" |
| `getStarted` | "Get Started" |
