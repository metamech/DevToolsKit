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

## Capture History Panel

The `ScreenCapturePanel` provides a browsable history of captures with thumbnails, metadata, and quick export actions.

```swift
import DevToolsKitScreenCapture

let captureStore = ScreenCaptureStore(
    storageDirectory: appSupportURL.appendingPathComponent("ScreenCaptures"),
    maxCaptures: 100  // optional FIFO limit
)
try captureStore.loadAll()

manager.register(ScreenCapturePanel(store: captureStore))
```

### Saving Captures

After taking a capture, persist it to the store:

```swift
let result = try await ScreenCapturer.captureWindow()
try captureStore.save(result)
```

The store writes three files per capture: `{uuid}.json` (metadata), `{uuid}.png` (full image), and `{uuid}.thumb.png` (200×200 thumbnail).

### Filtering

```swift
// Filter by capture mode
captureStore.filterMode = .window

// Filter by date range
captureStore.filterDateRange = startDate...endDate

// Read filtered results
let filtered = captureStore.filteredEntries
```

### Panel Features

- **Thumbnail grid** — `LazyVGrid` of capture cards with mode badge, dimensions, and timestamp
- **Detail view** — full-resolution image, metadata table, copy/delete actions
- **Mode filter** — toolbar picker to show only window, area, or full-screen captures
- **Storage info** — total capture count and disk usage displayed in toolbar
- **Context menu** — right-click to copy to clipboard or delete

### Diagnostic Export

`ScreenCaptureStore` conforms to `DiagnosticProvider`, reporting total count, mode breakdown, storage bytes, and recent entries (metadata only).

```swift
manager.registerDiagnosticProvider(captureStore)
```

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
