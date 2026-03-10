[< Guide](GUIDE.md) | [Index](../INDEX.md)

# DevToolsKitScreenCapture API Reference

> Source: `Sources/DevToolsKitScreenCapture/`
> Since: 0.5.0

## ScreenCaptureMode

```swift
public enum ScreenCaptureMode: String, Sendable, CaseIterable {
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

## Platform Support

| Feature | macOS | iOS/visionOS | tvOS/watchOS |
|---------|-------|-------------|--------------|
| Window capture | NSView bitmap | UIGraphicsImageRenderer | Throws `.unsupportedPlatform` |
| Area selection | ScreenCaptureKit + overlay | UIKit overlay + crop | Throws `.unsupportedPlatform` |
| Full screen | ScreenCaptureKit | Same as window | Throws `.unsupportedPlatform` |
| Clipboard | NSPasteboard | UIPasteboard | Throws `.unsupportedPlatform` |
