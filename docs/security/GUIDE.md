[< Core](../core/QUICK_START.md) | [Index](../INDEX.md) | [API >](API.md)

# DevToolsKitSecurity Guide

Permission management, sandbox validation, security-scoped bookmarks, and command policy enforcement.

## Setup

```swift
.product(name: "DevToolsKitSecurity", package: "DevToolsKit")
```

```swift
import DevToolsKitSecurity
```

## Permission Configuration

Define per-operation and per-category permissions:

```swift
var config = PermissionConfiguration.defaultPermissions
config.perOperation["Deploy"] = .deny
config.perCategory[.execute] = .ask

let level = config.permission(for: "Deploy")  // .deny
let level2 = config.permission(for: "Bash")   // .ask
```

Merge project overrides on top of app defaults:

```swift
let effective = appConfig.merged(with: projectOverride)
```

## Permission Handler

Implement `PermissionHandler` for custom permission UI:

```swift
struct MyPermissionHandler: PermissionHandler {
    func requestPermission(_ request: PermissionRequest) async -> PermissionResponse {
        // Show UI, return .allow / .allowForSession / .deny
    }
}
```

Use `AutoApprovePermissionHandler` for testing or trusted environments.

## Command Policy

Validate commands against security deny patterns:

```swift
let policy = CommandPolicy.default
let (denied, reason) = policy.isDenied("rm -rf /")
// denied: true, reason: "Command matches security deny pattern: ..."
```

## Sandbox Validation

Check paths against allowed directories:

```swift
let allowed = FileSystemUtility.isAllowed(fileURL, in: allowedPaths)

// Or throw on violation:
try FileSystemUtility.validateSandbox(path: path, url: url, allowedPaths: allowedPaths)
```

## Bookmarks

Persist file access across app launches in sandboxed apps:

```swift
let manager = BookmarkManager()
let data = try manager.createBookmark(for: projectURL)
// Persist `data` to UserDefaults or disk

let (url, stopAccessing) = try manager.resolveBookmark(data)
defer { stopAccessing() }
// Use `url`...
```

## Audit Panel

Register the permission audit panel to view permission decisions:

```swift
let auditStore = PermissionAuditStore()
manager.register(PermissionAuditPanel(store: auditStore))

// Record decisions:
auditStore.record(PermissionAuditEntry(
    operationName: "Write",
    category: .write,
    configuredLevel: .ask,
    source: .appDefault,
    decision: .allow,
    argumentsSummary: "file: config.json"
))
```
