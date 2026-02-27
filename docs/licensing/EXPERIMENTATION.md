# Experimentation

[< Feature Flags](FEATURE_FLAGS.md) | [Index](../INDEX.md) | [License Backends >](LICENSE_BACKENDS.md)

> **Module:** `DevToolsKitLicensing`
> **Since:** 0.2.0

## Overview

Feature flags can optionally include percentage rollouts and multi-cohort experiments. Assignment is deterministic — the same enrollment ID always gets the same bucket/cohort for a given flag.

## Percentage Rollouts

Gradually enable a flag for a percentage of users:

```swift
FeatureFlagDefinition(
    id: "myapp.new-search",
    name: "New Search",
    description: "Redesigned search experience",
    category: "Experimental",
    defaultEnabled: false,
    rollout: RolloutDefinition(percentage: 25)  // 25% of users
)
```

The rollout uses a hash-based bucket (SHA256 of enrollment ID + flag ID, mod 100). Users with bucket < percentage get the flag enabled. Percentage is clamped to 0–100.

## Multi-Cohort Experiments

Assign users to named cohorts with relative weights:

```swift
FeatureFlagDefinition(
    id: "myapp.checkout-flow",
    name: "Checkout Flow",
    description: "A/B test for checkout redesign",
    category: "Experimental",
    defaultEnabled: false,
    experiment: CohortDefinition(
        cohorts: [
            Cohort(name: "control", weight: 50),
            Cohort(name: "variant-a", weight: 25),
            Cohort(name: "variant-b", weight: 25),
        ],
        targeting: []  // Optional targeting rules
    )
)
```

When a user is assigned to any cohort, the flag is enabled. Check the assigned cohort:

```swift
if let state = licensing.flagState(for: "myapp.checkout-flow") {
    switch state.cohort {
    case "control": showClassicCheckout()
    case "variant-a": showRedesignA()
    case "variant-b": showRedesignB()
    default: showClassicCheckout()
    }
}
```

Weights are relative (don't need to sum to 100).

## Targeting Rules

Limit rollouts and experiments to specific audiences:

```swift
RolloutDefinition(
    percentage: 50,
    targeting: [
        .minimumOSVersion("15.2"),
        .language("en"),
    ]
)
```

All rules must pass for enrollment. Available rules:

| Rule | Evaluation |
|------|-----------|
| `.minimumAppVersion(String)` | `CFBundleShortVersionString >= value` |
| `.maximumAppVersion(String)` | `CFBundleShortVersionString <= value` |
| `.minimumOSVersion(String)` | `ProcessInfo OS version >= value` |
| `.maximumOSVersion(String)` | `ProcessInfo OS version <= value` |
| `.language(String)` | `Locale.current.language.languageCode == code` |
| `.region(String)` | `Locale.current.region == code` |

All evaluation is local — no network or GPS required. Version comparisons handle numeric components correctly (`"15.2" < "15.10"`).

## Enrollment ID

Each user gets a stable UUID stored in `UserDefaults`, used for deterministic bucket assignment:

```swift
licensing.enrollmentID         // Current UUID
licensing.enrollmentIDExpiresAt // When it auto-regenerates
licensing.resetEnrollmentID()   // Force new UUID (re-rolls all experiments)
```

Default lifetime: 90 days. After expiration, a new UUID is generated on next access, which may reassign cohorts.

## CohortResolver (Advanced)

For programmatic use outside the flag system:

```swift
let bucket = CohortResolver.bucket(enrollmentID: uuid, flagID: "myapp.test")  // 0..<100
let inRollout = CohortResolver.isInRollout(enrollmentID: uuid, flagID: "myapp.test", percentage: 25)
let cohort = CohortResolver.assignCohort(enrollmentID: uuid, flagID: "myapp.test", cohorts: cohorts)
```
