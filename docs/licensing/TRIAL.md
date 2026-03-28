# Trial Subsystem

`TrialManager` provides time-limited trial support backed by UserDefaults.

## Setup

```swift
let manager = LicensingManager(keyPrefix: "myapp", backend: myBackend)
manager.configureTrial(TrialConfiguration(durationDays: 14))
manager.trial?.startTrialIfNeeded()
```

## TrialConfiguration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `durationDays` | 14 | Trial length in days |
| `graceEnabled` | false | Reserved for future grace period support |

## TrialState

- `.notStarted` -- No trial has been started (first launch)
- `.active` -- Within the trial window
- `.expired` -- Trial period has elapsed

## UserDefaults Keys

All prefixed with `{keyPrefix}.trial.`:

| Key | Type | Description |
|-----|------|-------------|
| `startDate` | TimeInterval | First trial start (immutable once written) |
| `durationDays` | Int | Duration from config (written once) |
| `hasSeenWelcome` | Bool | Welcome screen shown |
| `wasEverLicensed` | Bool | Set on first activation, never auto-cleared |

## Anti-Tamper

- `startDate` is written once and never modified via public API
- State transitions are one-directional: `notStarted -> active -> expired`
- Once expired, stays expired regardless of system clock changes
- Only `resetTrial()` can revert to `.notStarted` (dev testing only)

## Key Properties

```swift
trial.state              // Current TrialState
trial.firstLaunchDate    // Date? -- nil if not started
trial.trialExpiryDate    // Date? -- computed from start + duration
trial.daysRemaining      // Int -- 0 if expired or not started
trial.isFirstLaunch      // Bool -- true if never started and welcome not seen
trial.hasSeenWelcome     // Bool -- read/write
trial.wasEverLicensed    // Bool -- read/write, survives resetTrial()
```

## Dev/Testing

```swift
// Skip welcome flow in dev builds
trial.skipWelcomeIfNeeded()  // Marks welcome seen + starts trial silently

// Reset trial for testing
trial.resetTrial()  // Clears start date, duration, welcome flag; keeps wasEverLicensed
```
