import Foundation

/// Main coordinator for screen capture operations.
///
/// Delegates to platform-specific implementations based on the current OS.
/// On unsupported platforms (tvOS, watchOS), all methods throw
/// ``ScreenCaptureError/unsupportedPlatform``.
///
/// Since 0.5.0
@MainActor
public enum ScreenCapturer: Sendable {
    /// Capture the key/frontmost window.
    ///
    /// - Returns: The captured image result.
    /// - Throws: ``ScreenCaptureError`` if capture fails.
    public static func captureWindow() async throws -> ScreenCaptureResult {
        try await PlatformCapturer.captureWindow()
    }

    /// Begin interactive area selection, returns result when user completes.
    ///
    /// Presents a transparent overlay allowing the user to drag-select a region.
    ///
    /// - Returns: The captured image result for the selected region.
    /// - Throws: ``ScreenCaptureError`` if capture fails or is cancelled.
    public static func captureArea() async throws -> ScreenCaptureResult {
        try await PlatformCapturer.captureArea()
    }

    /// Capture the full screen.
    ///
    /// - Returns: The captured image result of the entire display.
    /// - Throws: ``ScreenCaptureError`` if capture fails.
    public static func captureFullScreen() async throws -> ScreenCaptureResult {
        try await PlatformCapturer.captureFullScreen()
    }

    /// Capture with a specified mode.
    ///
    /// - Parameter mode: The capture mode to use.
    /// - Returns: The captured image result.
    /// - Throws: ``ScreenCaptureError`` if capture fails.
    public static func capture(mode: ScreenCaptureMode) async throws -> ScreenCaptureResult {
        switch mode {
        case .window:
            try await captureWindow()
        case .area:
            try await captureArea()
        case .fullScreen:
            try await captureFullScreen()
        }
    }
}
