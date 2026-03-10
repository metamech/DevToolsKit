[< Guide](GUIDE.md) | [Index](../INDEX.md)

# DevToolsKitIssueCapture API Reference

> Source: `Sources/DevToolsKitIssueCapture/`
> Since: 0.5.0

## IssueCaptureProvider

```swift
@MainActor
public protocol IssueCaptureProvider: Identifiable, Sendable where ID == String {
    var id: String { get }
    var displayName: String { get }
    func captureCurrentState() async -> [String: String]
    var expectedStateFields: [IssueCaptureField] { get }
}
```

## IssueCaptureField

```swift
public enum IssueCaptureField: Sendable, Identifiable {
    case text(id: String, label: String, placeholder: String)
    case quickSelect(id: String, label: String, options: [String])
    case multiSelect(id: String, label: String, options: [String])

    public var id: String { get }
    public var label: String { get }
}
```

## IssueCapture

```swift
public struct IssueCapture: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let timestamp: Date
    public let providerID: String
    public let providerName: String
    public let capturedState: [String: String]
    public let expectedState: [String: String]
    public let notes: String?
    public let tags: [String]
    public let screenshotData: Data?
}
```

## IssueCaptureStore

```swift
@MainActor @Observable
public final class IssueCaptureStore: Sendable {
    // Properties
    public private(set) var captures: [IssueCapture]
    public var filterProviderID: String?
    public var filterTag: String?
    public var searchText: String
    public var filterDateRange: ClosedRange<Date>?
    public let maxCaptures: Int?
    public let storageDirectory: URL

    // Computed
    public var filteredCaptures: [IssueCapture]
    public var knownProviderIDs: [String]
    public var knownTags: [String]
    public var capturesByProvider: [String: [IssueCapture]]
    public var captureFrequency: [(date: Date, count: Int)]

    // Init
    public init(storageDirectory: URL, maxCaptures: Int? = nil)

    // CRUD
    public func save(_ capture: IssueCapture) throws
    public func delete(id: UUID)
    public func delete(ids: Set<UUID>)
    public func loadAll() throws

    // Analysis
    public func commonExpectedValues(fieldID: String) -> [(value: String, count: Int)]

    // Export
    public func exportFiltered() throws -> Data
}
```

Conforms to `DiagnosticProvider` with section name `"issueCaptures"`.

## IssueCapturePanel

```swift
public struct IssueCapturePanel: DevToolPanel {
    public let id = "devtools.issueCapture"
    public let icon = "camera.viewfinder"
    public let keyboardShortcut = DevToolsKeyboardShortcut(key: "r") // ⌘⌥R

    public init(store: IssueCaptureStore, providers: [any IssueCaptureProvider])
}
```

## QuickCaptureView

```swift
@MainActor
public struct QuickCaptureView: View {
    public init(store: IssueCaptureStore, providers: [any IssueCaptureProvider])
}
```

### View Modifier

```swift
extension View {
    public func quickCaptureSheet(
        isPresented: Binding<Bool>,
        store: IssueCaptureStore,
        providers: [any IssueCaptureProvider]
    ) -> some View
}
```
