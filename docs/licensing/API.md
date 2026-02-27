# Licensing & Feature Flags API Reference

[< License Backends](LICENSE_BACKENDS.md) | [Index](../INDEX.md)

> **Source:** `Sources/DevToolsKitLicensing/`
> **Since:** 0.2.0

## LicensingManager

```swift
@MainActor @Observable
public final class LicensingManager: Sendable {
    public init(keyPrefix: String, backend: (any LicenseBackend)? = nil)

    // Flag registration
    public func registerFlags(_ flags: [FeatureFlagDefinition])
    public func registerFlag(_ flag: FeatureFlagDefinition)
    public var flagDefinitions: [String: FeatureFlagDefinition]
    public var flagOrder: [String]

    // Flag resolution
    public func isEnabled(_ flagID: String) -> Bool
    public func flagState(for flagID: String) -> FeatureFlagState?
    public var allFlagStates: [FeatureFlagState]

    // Developer overrides (persisted to UserDefaults)
    public func setOverride(_ enabled: Bool, for flagID: String, expiresAfter ttl: Duration? = nil)
    public func clearOverride(for flagID: String)
    public func clearAllOverrides()

    // License
    public var licenseStatus: DevToolsLicenseStatus
    public func activate(with credential: LicenseCredential) async throws
    public func validate() async throws
    public func deactivate() async throws
    public func hasEntitlement(_ name: String) -> Bool

    // Enrollment
    public var enrollmentID: UUID
    public var enrollmentIDExpiresAt: Date
    public func resetEnrollmentID()

    // Observation
    public var stateVersion: UInt64
    public func stateChanges(for flagID: String) -> AsyncStream<FeatureFlagState>
}
```

Conforms to `DiagnosticProvider` (sectionName: `"licensing"`).

## FeatureFlagDefinition

```swift
public struct FeatureFlagDefinition: Sendable, Hashable, Identifiable {
    public let id: String                          // Reverse-domain ID
    public let name: String                        // Display name
    public let description: String
    public let category: String                    // Grouping in panel
    public let defaultEnabled: Bool                // default: false
    public let requiredTier: LicenseTier           // default: .free
    public let rollout: RolloutDefinition?         // default: nil
    public let experiment: CohortDefinition?       // default: nil
}
```

## FeatureFlagState

```swift
public struct FeatureFlagState: Sendable {
    public let definition: FeatureFlagDefinition
    public let isEnabled: Bool
    public let isOverridden: Bool
    public let isGated: Bool
    public let cohort: String?
    public let overrideExpiresAt: Date?
}
```

## Experimentation Types

```swift
public struct RolloutDefinition: Sendable, Hashable, Codable {
    public let percentage: Int       // Clamped 0–100
    public let targeting: [TargetingRule]
}

public struct CohortDefinition: Sendable, Hashable, Codable {
    public let cohorts: [Cohort]
    public let targeting: [TargetingRule]
}

public struct Cohort: Sendable, Hashable, Codable {
    public let name: String
    public let weight: Int           // Relative weight
}

public enum TargetingRule: Sendable, Hashable, Codable {
    case minimumAppVersion(String)
    case maximumAppVersion(String)
    case minimumOSVersion(String)
    case maximumOSVersion(String)
    case language(String)
    case region(String)
    public func isSatisfied() -> Bool
}
```

## CohortResolver

```swift
public enum CohortResolver {
    public static func bucket(enrollmentID: UUID, flagID: String) -> Int
    public static func assignCohort(enrollmentID: UUID, flagID: String, cohorts: [Cohort]) -> String?
    public static func isInRollout(enrollmentID: UUID, flagID: String, percentage: Int) -> Bool
}
```

## EnrollmentID

```swift
@MainActor
public final class EnrollmentID: Sendable {
    public var value: UUID
    public var generatedAt: Date
    public var expiresAt: Date
    public init(keyPrefix: String, regenerationInterval: TimeInterval = 90 * 24 * 60 * 60)
    @discardableResult public func reset() -> UUID
}
```

## License Types

```swift
public enum DevToolsLicenseStatus: String, Sendable, Codable {
    case unconfigured, active, offlineValid, inactive, invalid, pending
}

public enum LicenseTier: Sendable, Hashable, Codable {
    case free, premium, custom(String)
}

public enum LicenseCredential: Sendable {
    case licenseKey(String), offlineToken(String)
}

public enum ValidationMode: String, Sendable, CaseIterable, Codable {
    case offline, online
}

@MainActor
public protocol LicenseBackend: Sendable {
    var status: DevToolsLicenseStatus { get }
    var activeEntitlements: Set<String> { get }
    func activate(with credential: LicenseCredential) async throws
    func validate() async throws
    func deactivate() async throws
}
```

## FeatureFlagsPanel

```swift
public struct FeatureFlagsPanel: DevToolPanel {
    public let id = "devtools.feature-flags"   // ⌘⌥F
    public init(licensing: LicensingManager)
}
```
