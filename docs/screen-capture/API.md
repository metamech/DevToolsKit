[< Guide](GUIDE.md) | [Index](../INDEX.md)

# DevToolsKitScreenCapture API Reference

> Source: `Sources/DevToolsKitScreenCapture/`
> Since: 0.5.0

## ScreenCaptureMode

```swift
public enum ScreenCaptureMode: String, Codable, Sendable, CaseIterable {
    case window
    case area
    case fullScreen
}
```

## ScreenCaptureResult

```swift
public struct ScreenCaptureResult: Sendable {
    public let imageData: Data
    public let size: CGSize
    public let mode: ScreenCaptureMode
    public let timestamp: Date
    public let displayScale: CGFloat

    public init(imageData: Data, size: CGSize, mode: ScreenCaptureMode,
                timestamp: Date = Date(), displayScale: CGFloat = 1.0)
}
```

## ScreenCaptureError

```swift
public enum ScreenCaptureError: Error, Sendable {
    case unsupportedPlatform
    case capturePermissionDenied
    case captureFailed(String)
    case noWindowAvailable
    case userCancelled
}
```

## ScreenCapturer

```swift
@MainActor
public enum ScreenCapturer: Sendable {
    public static func captureWindow() async throws -> ScreenCaptureResult
    public static func captureArea() async throws -> ScreenCaptureResult
    public static func captureFullScreen() async throws -> ScreenCaptureResult
    public static func capture(mode: ScreenCaptureMode) async throws -> ScreenCaptureResult
}
```

## ScreenCaptureExporter

```swift
public enum ScreenCaptureExporter: Sendable {
    @MainActor
    public static func copyToClipboard(_ result: ScreenCaptureResult) throws
    public static func save(_ result: ScreenCaptureResult, to url: URL,
                            format: ScreenCaptureFormat = .png) throws
    public static func data(from result: ScreenCaptureResult,
                            format: ScreenCaptureFormat) throws -> Data
}
```

## ScreenCaptureFormat

```swift
public enum ScreenCaptureFormat: String, Sendable, CaseIterable {
    case png
    case jpeg
    case tiff
}
```

## WindowPickerView (macOS only)

```swift
@MainActor
public struct WindowPickerView: View {
    public init(onSelect: @escaping (NSWindow) -> Void)
}
```

## ScreenCaptureEntry

> Since: 0.5.0

```swift
public struct ScreenCaptureEntry: Codable, Sendable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let mode: ScreenCaptureMode
    public let imageSize: CGSize
    public let displayScale: CGFloat
    public let imageDataSize: Int

    public init(id: UUID = UUID(), timestamp: Date, mode: ScreenCaptureMode,
                imageSize: CGSize, displayScale: CGFloat, imageDataSize: Int)
    public init(result: ScreenCaptureResult)
}
```

## ScreenCaptureStore

> Since: 0.5.0

```swift
@MainActor @Observable
public final class ScreenCaptureStore: Sendable {
    public private(set) var entries: [ScreenCaptureEntry]
    public var filterMode: ScreenCaptureMode?
    public var filterDateRange: ClosedRange<Date>?
    public var filteredEntries: [ScreenCaptureEntry] { get }
    public let storageDirectory: URL
    public let maxCaptures: Int?
    public var totalStorageBytes: Int { get }

    public init(storageDirectory: URL, maxCaptures: Int? = nil)

    @discardableResult
    public func save(_ result: ScreenCaptureResult) throws -> ScreenCaptureEntry
    public func delete(id: UUID)
    public func delete(ids: Set<UUID>)
    public func loadAll() throws

    public func imageData(for entry: ScreenCaptureEntry) -> Data?
    public func thumbnailData(for entry: ScreenCaptureEntry) -> Data?
}

extension ScreenCaptureStore: DiagnosticProvider {
    public var sectionName: String { "screenCaptures" }
}
```

## ScreenCapturePanel

> Since: 0.5.0

```swift
public struct ScreenCapturePanel: DevToolPanel {
    public let id: String       // "devtools.screenCapture"
    public let title: String    // "Screen Captures"
    public let icon: String     // "photo.on.rectangle"
    public let keyboardShortcut: DevToolsKeyboardShortcut?  // ⌘⌥H

    public init(store: ScreenCaptureStore)
    public func makeBody() -> AnyView
}
```

## Platform Support

| Feature | macOS | iOS/visionOS | tvOS/watchOS |
|---------|-------|-------------|--------------|
| Window capture | NSView bitmap | UIGraphicsImageRenderer | Throws `.unsupportedPlatform` |
| Area selection | ScreenCaptureKit + overlay | UIKit overlay + crop | Throws `.unsupportedPlatform` |
| Full screen | ScreenCaptureKit | Same as window | Throws `.unsupportedPlatform` |
| Clipboard | NSPasteboard | UIPasteboard | Throws `.unsupportedPlatform` |
