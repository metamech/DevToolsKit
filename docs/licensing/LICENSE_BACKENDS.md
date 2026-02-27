# License Backends

[< Experimentation](EXPERIMENTATION.md) | [Index](../INDEX.md) | [API Reference >](API.md)

> **Module:** `DevToolsKitLicensing`
> **Since:** 0.2.0

## Overview

Licensing in DevToolsKitLicensing is decoupled via the `LicenseBackend` protocol. The licensing module itself contains no network code — backends are provided by companion modules.

## LicenseBackend Protocol

```swift
@MainActor
public protocol LicenseBackend: Sendable {
    var status: DevToolsLicenseStatus { get }
    var activeEntitlements: Set<String> { get }
    func activate(with credential: LicenseCredential) async throws
    func validate() async throws
    func deactivate() async throws
}
```

## License Status

```swift
public enum DevToolsLicenseStatus: String, Sendable, Codable {
    case unconfigured   // No backend or no activation yet
    case active         // Online-validated license
    case offlineValid   // Valid offline token
    case inactive       // Previously active, now expired
    case invalid        // Key/token invalid
    case pending        // Validation in progress
}
```

## Credential Types

```swift
public enum LicenseCredential: Sendable {
    case licenseKey(String)     // Online activation key
    case offlineToken(String)   // Offline validation token
}
```

## Built-in Backend Modules

### DevToolsKitLicensingSeat (Website Distribution)

```swift
import DevToolsKitLicensingSeat

let backend = LicenseSeatBackend(/* configuration */)
let licensing = LicensingManager(keyPrefix: "myapp", backend: backend)
```

Uses [LicenseSeat](https://github.com/licenseseat/licenseseat-swift) for online key activation and offline token validation.

### DevToolsKitLicensingStoreKit (App Store Distribution)

```swift
import DevToolsKitLicensingStoreKit

let backend = StoreKitBackend(/* configuration */)
let licensing = LicensingManager(keyPrefix: "myapp", backend: backend)
```

Uses StoreKit 2 for App Store receipt validation.

## Without a Backend

If no backend is provided, `LicensingManager` starts with `status = .unconfigured`. Feature flags still work — only tier-gated flags (`.premium`, `.custom`) are affected (they resolve as gated/disabled).

```swift
let licensing = LicensingManager(keyPrefix: "myapp")
// .free tier flags work normally
// .premium tier flags are disabled until a backend is configured
```

## License Actions via LicensingManager

```swift
try await licensing.activate(with: .licenseKey("XXXX-XXXX"))
try await licensing.validate()
try await licensing.deactivate()

licensing.licenseStatus           // Current DevToolsLicenseStatus
licensing.hasEntitlement("pro")   // Check backend entitlements
```

## License Tiers

| Tier | Gating Rule |
|------|-------------|
| `.free` | Always satisfied |
| `.premium` | Status must be `.active` or `.offlineValid` |
| `.custom("name")` | `"name"` must be in `backend.activeEntitlements` |

Developer overrides bypass tier gating entirely.
