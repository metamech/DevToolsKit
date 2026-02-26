# API Reference: Export

> Source: `Sources/DevToolsKit/Export/`

## DiagnosticProvider

```swift
@MainActor
public protocol DiagnosticProvider {
    var sectionName: String { get }
    func collect() async -> any Codable & Sendable
}
```

Implement to contribute a custom section to the diagnostic report. The `sectionName` becomes a key in `DiagnosticReport.customSections`.

## DiagnosticReport

```swift
public struct DiagnosticReport: Codable, Sendable {
    public let appName: String
    public let appVersion: String
    public let macOSVersion: String
    public let hardware: HardwareInfo
    public let developerSettings: DeveloperSettingsSnapshot
    public let recentLogEntries: [LogEntrySnapshot]
    public let customSections: [String: AnyCodable]
    public let timestamp: Date

    public init(appName:appVersion:macOSVersion:hardware:developerSettings:recentLogEntries:customSections:timestamp:)
}
```

### DiagnosticReport.HardwareInfo

```swift
public struct HardwareInfo: Codable, Sendable {
    public let model: String
    public let chipArchitecture: String
    public let memoryGB: Int
    public let processorCount: Int

    public init(model:chipArchitecture:memoryGB:processorCount:)
}
```

### DiagnosticReport.DeveloperSettingsSnapshot

```swift
public struct DeveloperSettingsSnapshot: Codable, Sendable {
    public let isDeveloperMode: Bool
    public let logLevel: String

    public init(isDeveloperMode:logLevel:)
}
```

### DiagnosticReport.LogEntrySnapshot

```swift
public struct LogEntrySnapshot: Codable, Sendable {
    public let timestamp: Date
    public let level: String
    public let source: String
    public let message: String

    public init(timestamp:level:source:message:)
}
```

## DiagnosticExporter

```swift
@MainActor
public struct DiagnosticExporter {
    public init(
        manager: DevToolsManager,
        logStore: DevToolsLogStore? = nil,
        appName: String? = nil
    )

    public func export() async
}
```

Collects all registered providers, builds a `DiagnosticReport`, presents an `NSSavePanel`, and writes pretty-printed JSON.

## AnyCodable

```swift
public struct AnyCodable: Codable, Sendable {
    public init(_ value: some Codable & Sendable)
    public func encode(to encoder: Encoder) throws
    public init(from decoder: Decoder) throws
}
```

Type-erased Codable wrapper used for heterogeneous custom sections in `DiagnosticReport`.
