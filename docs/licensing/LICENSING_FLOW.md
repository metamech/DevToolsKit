# Licensing Flow

State-driven licensing flows integrated with WelcomeKit.

## State Machine

`LicensingFlowResolver` maps `EffectiveLicenseState` to WelcomeKit screens:

```
effectiveState          Screen                    Mode
─────────────────────────────────────────────────────────
.licensed            →  nil (no flow)              —
.trial(days)         →  nil (banner only)          —
.unlicensed          →  Welcome + Features +       blocking
                        Trial Start
.trialExpired        →  Trial Expired Notice +     blocking
                        Purchase + Key Entry
.expired             →  License Expired Notice +   blocking
                        Purchase + Key Entry
```

## Integration

One-liner for full licensing flow:

```swift
ContentView()
    .licensingFlow(
        offering: .myOffering,
        manager: licensingManager,
        devSimulationEnabled: AppEnvironment.isLicenseTestingEnabled
    )
```

This combines:
- **WelcomeKit blocking overlay** for licensing gates (unlicensed, expired, trial expired)
- **Trial banner** (non-blocking pill) showing "X days remaining | Buy Now"

## LicensingPages Factories

Build individual pages from an offering:

```swift
LicensingPages.hero(from: offering)              // App icon + name + tagline
LicensingPages.features(from: offering)           // Feature list
LicensingPages.trialStart(offering:manager:)      // "Start Free Trial" CTA
LicensingPages.purchase(offering:manager:)         // Pricing tiers + purchase
LicensingPages.licenseKeyEntry(manager:)           // Key input + activate
LicensingPages.trialExpiredNotice(offering:)       // "Trial Has Ended"
LicensingPages.licenseExpiredNotice(offering:)     // "License Has Expired"
LicensingPages.purchaseSuccess(offering:)          // Confirmation
```

## Custom Flows

Compose pages manually for custom flows:

```swift
let screen = WelcomeScreen(
    id: "my-custom-flow",
    pages: [
        LicensingPages.hero(from: offering),
        .custom { AnyView(MyCustomPage()) },
        LicensingPages.trialStart(offering: offering, manager: manager),
    ],
    presentationMode: .blocking
)
```

## Trial Banner

Standalone modifier for the non-blocking trial countdown:

```swift
ContentView()
    .trialBanner(manager: licensingManager) {
        showPurchaseSheet = true
    }
```

Shows "X days remaining | Buy Now" pill in top-trailing corner. Orange accent when <= 3 days.

## Dev Simulation

When `devSimulationEnabled` is true and the backend is `MockLicenseBackend`, purchase pages show "Simulate Success" and "Simulate Failure" buttons. These are gated by `#if ENABLE_LICENSE_TESTING` and compiled out of Release builds.

## Dev/Deploy Default

Dev and deploy builds use `MockLicenseBackend.licensed()` which starts in `.active` state. The flow resolver returns `nil` for `.licensed`, so no licensing flow is shown during normal development. Use the FeatureFlagsPanel to switch states for testing.
