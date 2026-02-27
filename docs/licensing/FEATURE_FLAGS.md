# Feature Flags Guide

[Index](../INDEX.md) | [Experimentation >](EXPERIMENTATION.md)

> **Module:** `DevToolsKitLicensing` — depends on DevToolsKit + [swift-metrics](https://github.com/apple/swift-metrics)
> **Since:** 0.2.0

## Overview

DevToolsKitLicensing provides a feature flag system with license-tier gating, developer overrides, and optional experimentation (cohorts, rollouts, targeting). Feature flags are resolved locally with no network dependency.

## Installation

```swift
// Package.swift
.product(name: "DevToolsKitLicensing", package: "DevToolsKit")
```

## Setup

```swift
import DevToolsKit
import DevToolsKitLicensing

let licensing = LicensingManager(keyPrefix: "myapp")

// Define flags
licensing.registerFlags([
    FeatureFlagDefinition(
        id: "myapp.new-editor",
        name: "New Editor",
        description: "Experimental block editor",
        category: "Experimental",
        defaultEnabled: false
    ),
    FeatureFlagDefinition(
        id: "myapp.dark-sidebar",
        name: "Dark Sidebar",
        description: "Always-dark sidebar variant",
        category: "UI",
        defaultEnabled: true
    ),
])

// Register the panel and diagnostic provider
manager.register(FeatureFlagsPanel(licensing: licensing))
manager.registerDiagnosticProvider(licensing)
```

## Checking Flags

```swift
if licensing.isEnabled("myapp.new-editor") {
    showBlockEditor()
} else {
    showClassicEditor()
}
```

For full state including override/gating info:

```swift
if let state = licensing.flagState(for: "myapp.new-editor") {
    print(state.isEnabled)     // Final resolved value
    print(state.isOverridden)  // Developer override active?
    print(state.isGated)       // Blocked by license tier?
    print(state.cohort)        // Experiment cohort (if any)
}
```

## Resolution Order

1. **Developer override** (non-expired) → use override value
2. **License tier gating** → if tier unsatisfied, disabled
3. **Experiment cohort** → assigned cohort means enabled
4. **Percentage rollout** → bucket < percentage means enabled
5. **`defaultEnabled`** from definition

## License-Gated Flags

Require a specific license tier:

```swift
FeatureFlagDefinition(
    id: "myapp.pro-feature",
    name: "Pro Feature",
    description: "Available to premium users",
    category: "Pro",
    defaultEnabled: true,
    requiredTier: .premium  // Requires active license
)
```

Tiers: `.free` (always satisfied), `.premium` (requires active/offlineValid), `.custom("entitlement-name")`.

## Developer Overrides

Override any flag at runtime — overrides bypass license gating:

```swift
licensing.setOverride(true, for: "myapp.new-editor")                    // Permanent
licensing.setOverride(true, for: "myapp.new-editor", expiresAfter: .hours(2))  // TTL
licensing.clearOverride(for: "myapp.new-editor")
licensing.clearAllOverrides()
```

Overrides persist to `UserDefaults`. TTL overrides auto-expire.

## Observing Changes

```swift
for await state in licensing.stateChanges(for: "myapp.new-editor") {
    print("Flag now: \(state.isEnabled)")
}
```

## Feature Flags Panel (⌘⌥F)

Three tabs:
- **Flags** — Searchable list grouped by category with toggle overrides, status dots (green/gray/purple/orange), cohort badges, TTL countdown
- **License** — Current license status, active entitlements, activate/validate/deactivate actions
- **Enrollment** — Enrollment UUID, copy/reset, expiration countdown

## Analytics

Flag checks, cohort assignments, and overrides automatically emit swift-metrics counters (labels: `devtools.feature_flag.check`, `.cohort_assignment`, `.override`). If using `DevToolsKitMetrics`, these appear in the metrics panel.
