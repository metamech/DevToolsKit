[< Guide](GUIDE.md) | [Index](../INDEX.md)

# DevToolsKitSecurity API Reference

> Source: `Sources/DevToolsKitSecurity/`
> Since: 0.4.0

## Core Types

### RiskLevel
```swift
public enum RiskLevel: String, Sendable, Codable, Hashable {
    case low, medium, high
}
```

### PermissionLevel
```swift
public enum PermissionLevel: String, Codable, Sendable, Hashable {
    case allow, ask, deny
}
```

### OperationCategory
```swift
public enum OperationCategory: String, Codable, Sendable, Hashable {
    case read, write, execute, skill

    public static let defaultMapping: [String: OperationCategory]
    public static func category(for operationName: String) -> OperationCategory
    public static func category(for operationName: String, using mapping: [String: OperationCategory]) -> OperationCategory
}
```

### PermissionRequest
```swift
public struct PermissionRequest: Sendable {
    public let operationName: String
    public let operationCategory: OperationCategory
    public let arguments: [String: String]
    public let riskLevel: RiskLevel
}
```

### PermissionResponse
```swift
public enum PermissionResponse: Sendable, Codable, Equatable, Hashable {
    case allow, allowForSession, deny
}
```

### PermissionConfiguration
```swift
public struct PermissionConfiguration: Codable, Sendable, Hashable {
    public var perOperation: [String: PermissionLevel]
    public var perCategory: [OperationCategory: PermissionLevel]

    public func permission(for operationName: String) -> PermissionLevel
    public func merged(with overrides: PermissionConfiguration) -> PermissionConfiguration
    public static let defaultPermissions: PermissionConfiguration
}
```

### PermissionHandler
```swift
public protocol PermissionHandler: Sendable {
    func requestPermission(_ request: PermissionRequest) async -> PermissionResponse
}

public struct AutoApprovePermissionHandler: PermissionHandler
```

### PermissionAuditEntry
```swift
public struct PermissionAuditEntry: Sendable, Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let operationName: String
    public let category: OperationCategory
    public let configuredLevel: PermissionLevel
    public let source: PermissionSource
    public let decision: PermissionResponse
    public let argumentsSummary: String
}
```

### PermissionSource
```swift
public enum PermissionSource: String, Codable, Sendable, Hashable {
    case appDefault, projectOverride, sessionOverride
}
```

## Policy

### CommandPolicy
```swift
public struct CommandPolicy: Codable, Sendable {
    public let deniedPatterns: [String]
    public func isDenied(_ command: String) -> (denied: Bool, reason: String?)
    public static let `default`: CommandPolicy
}
```

## Sandbox

### FileSystemUtility
```swift
public struct FileSystemUtility: Sendable {
    public static func resolveURL(from path: String, workingDirectory: URL) -> URL
    public static func standardizeURL(_ url: URL) -> URL
    public static func standardizePath(_ url: URL) -> String
    public static func isAllowed(_ url: URL, in allowedPaths: Set<URL>) -> Bool
    public static func validateSandbox(path: String, url: URL, allowedPaths: Set<URL>) throws
    public static func standardizeAllowedPaths(_ allowedPaths: Set<URL>) -> [String]
    public static func isAllowed(_ url: URL, in standardizedAllowedPaths: [String]) -> Bool
    public static func relativePath(from fileURL: URL, to baseURL: URL) -> String
    public static func createSimpleBackup(of fileURL: URL) throws -> URL
    public static func createArchivedBackup(of fileURL: URL) throws -> URL
    public static func isFile(_ url: URL) -> Bool
    public static func isDirectory(_ url: URL) -> Bool
    public static func exists(_ url: URL) -> Bool
}
```

### SandboxError
```swift
public enum SandboxError: Error, LocalizedError, Sendable {
    case accessDenied(path: String)
}
```

## Bookmarks

### BookmarkManager
```swift
public struct BookmarkManager: Sendable {
    public func createBookmark(for url: URL) throws -> Data
    public func resolveBookmark(_ bookmarkData: Data) throws -> (url: URL, stopAccessing: @Sendable () -> Void)
}
```

## Panel

### PermissionAuditPanel
```swift
public struct PermissionAuditPanel: DevToolPanel {
    public let id = "devtools.permissions"
    public init(store: PermissionAuditStore)
}
```

### PermissionAuditStore
```swift
@MainActor @Observable
public final class PermissionAuditStore: Sendable {
    public private(set) var entries: [PermissionAuditEntry]
    public let maxEntries: Int
    public func record(_ entry: PermissionAuditEntry)
    public func clear()
}
```
