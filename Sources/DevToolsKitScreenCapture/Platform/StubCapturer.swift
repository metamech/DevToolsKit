#if os(tvOS) || os(watchOS)
import Foundation

/// Stub capturer for platforms that do not support screen capture.
@MainActor
enum PlatformCapturer {
    static func captureWindow() async throws -> ScreenCaptureResult {
        throw ScreenCaptureError.unsupportedPlatform
    }

    static func captureArea() async throws -> ScreenCaptureResult {
        throw ScreenCaptureError.unsupportedPlatform
    }

    static func captureFullScreen() async throws -> ScreenCaptureResult {
        throw ScreenCaptureError.unsupportedPlatform
    }
}
#endif
