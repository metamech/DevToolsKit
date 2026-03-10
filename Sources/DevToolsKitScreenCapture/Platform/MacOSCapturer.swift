#if canImport(AppKit)
import AppKit
import Foundation
import ScreenCaptureKit

/// macOS screen capture implementation using NSView rendering and ScreenCaptureKit.
@MainActor
enum PlatformCapturer {
    static func captureWindow() async throws -> ScreenCaptureResult {
        guard let keyWindow = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow else {
            throw ScreenCaptureError.noWindowAvailable
        }

        guard let contentView = keyWindow.contentView else {
            throw ScreenCaptureError.captureFailed("Window has no content view")
        }

        let scale = keyWindow.backingScaleFactor
        let bounds = contentView.bounds
        let bitmapSize = NSSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )

        guard let bitmapRep = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
            throw ScreenCaptureError.captureFailed("Failed to create bitmap representation")
        }

        bitmapRep.size = bitmapSize
        contentView.cacheDisplay(in: bounds, to: bitmapRep)

        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw ScreenCaptureError.captureFailed("Failed to encode PNG data")
        }

        return ScreenCaptureResult(
            imageData: pngData,
            size: bounds.size,
            mode: .window,
            displayScale: scale
        )
    }

    static func captureArea() async throws -> ScreenCaptureResult {
        // First, get the user's region selection via overlay
        let selectedRect: CGRect = try await withCheckedThrowingContinuation { continuation in
            let overlay = AreaSelectionOverlayWindow { rect in
                guard let rect else {
                    continuation.resume(throwing: ScreenCaptureError.userCancelled)
                    return
                }
                continuation.resume(returning: rect)
            }
            overlay.beginSelection()
        }

        // Capture the selected region using ScreenCaptureKit
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw ScreenCaptureError.captureFailed("No display available")
        }

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = selectedRect
        config.width = Int(selectedRect.width * scale)
        config.height = Int(selectedRect.height * scale)
        config.showsCursor = false

        let cgImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw ScreenCaptureError.captureFailed("Failed to encode PNG data")
        }

        return ScreenCaptureResult(
            imageData: pngData,
            size: selectedRect.size,
            mode: .area,
            displayScale: scale
        )
    }

    static func captureFullScreen() async throws -> ScreenCaptureResult {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw ScreenCaptureError.captureFailed("No display available")
        }

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(CGFloat(display.width) * scale)
        config.height = Int(CGFloat(display.height) * scale)
        config.showsCursor = false

        let cgImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw ScreenCaptureError.captureFailed("Failed to encode PNG data")
        }

        return ScreenCaptureResult(
            imageData: pngData,
            size: CGSize(width: display.width, height: display.height),
            mode: .fullScreen,
            displayScale: scale
        )
    }
}
#endif
