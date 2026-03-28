# MockLicenseBackend

A public mock backend for testing all license states in dev and deploy builds.

## Usage Pattern

```swift
#if ENABLE_LICENSE_TESTING
let backend = MockLicenseBackend.licensed()  // Defaults to active + premium
#else
let backend = LicenseSeatBackend(apiKey: "...", productSlug: "...")
#endif

let manager = LicensingManager(keyPrefix: "myapp", backend: backend)
```

The mock is always compiled into `DevToolsKitLicensing` (SPM packages can't use app build flags). Apps gate instantiation with `#if ENABLE_LICENSE_TESTING`. Dead code stripping removes it from Release binaries when unreferenced.

## Factory Methods

| Method | Status | Entitlements |
|--------|--------|-------------|
| `MockLicenseBackend()` | `.unconfigured` | empty |
| `MockLicenseBackend.licensed()` | `.active` | `["premium"]` |

## Simulation Controls

```swift
let mock = backend as! MockLicenseBackend

mock.simulateActivation()     // .active + ["premium"]
mock.simulateExpiration()     // .expired + []
mock.simulateDeactivation()   // .inactive + []
mock.simulateState(.offlineValid, entitlements: ["premium", "enterprise"])
```

## Custom Handlers

Override default behavior for specific test scenarios:

```swift
mock.activateHandler = { credential in
    // Custom activation logic
    throw MyError.networkTimeout  // Simulate failure
}

mock.simulatedDelay = .seconds(2)  // Simulate network latency
```

If no handler is set, `activate()` calls `simulateActivation()` and `deactivate()` calls `simulateDeactivation()`.

## FeatureFlagsPanel Integration

When the backend is `MockLicenseBackend`, the License tab in the FeatureFlagsPanel shows simulation controls (dropdown + apply button) for switching between states interactively.
