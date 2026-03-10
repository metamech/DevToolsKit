[Index](../INDEX.md) | [API Reference >](API.md)

# DevToolsKitScreenCapture Guide

> Since 0.5.0

Cross-platform in-app screen capture for Apple platform SwiftUI apps.

## Installation

```swift
.product(name: "DevToolsKitScreenCapture", package: "DevToolsKit")
```

## Quick Start

```swift
import DevToolsKitScreenCapture

// Capture the current window
let result = try await ScreenCapturer.captureWindow()

// Save as PNG
try ScreenCaptureExporter.save(result, to: outputURL)

// Or copy to clipboard
try ScreenCaptureExporter.copyToClipboard(result)
```

## Capture Modes

### Window Capture

Captures the key/frontmost window of your application.

```swift
let result = try await ScreenCapturer.captureWindow()
```

- **macOS**: Renders the window's content view to a bitmap
- **iOS/visionOS**: Uses `UIGraphicsImageRenderer` on the key window

### Area Selection

Presents a transparent overlay for drag-to-select region capture.

```swift
let result = try await ScreenCapturer.captureArea()
```

- **macOS**: Transparent `NSPanel` with crosshair cursor + ScreenCaptureKit
- **iOS**: Full-screen `UIViewController` overlay with pan gesture

Users can cancel by pressing Escape (macOS) or tapping outside (iOS), which throws `ScreenCaptureError.userCancelled`.

### Full Screen

Captures the entire display.

```swift
let result = try await ScreenCapturer.captureFullScreen()
```

- **macOS**: ScreenCaptureKit `SCScreenshotManager`
- **iOS**: Same as window capture (single-window platform)

## Export

```swift
// Convert format
let jpegData = try ScreenCaptureExporter.data(from: result, format: .jpeg)

// Save to file
try ScreenCaptureExporter.save(result, to: url, format: .tiff)
```

Supported formats: `.png`, `.jpeg`, `.tiff`

## Error Handling

```swift
do {
    let result = try await ScreenCapturer.capture(mode: .area)
} catch ScreenCaptureError.userCancelled {
    // User cancelled selection
} catch ScreenCaptureError.unsupportedPlatform {
    // tvOS/watchOS
} catch ScreenCaptureError.noWindowAvailable {
    // No window found
} catch {
    print("Capture failed: \(error)")
}
```
