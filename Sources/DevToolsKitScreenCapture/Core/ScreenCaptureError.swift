import Foundation

/// Errors that can occur during screen capture.
///
/// Since 0.5.0
public enum ScreenCaptureError: Error, Sendable {
    /// Screen capture is not supported on this platform.
    case unsupportedPlatform

    /// The user denied screen capture permission.
    case capturePermissionDenied

    /// Capture failed with a platform-specific reason.
    case captureFailed(String)

    /// No suitable window was available for capture.
    case noWindowAvailable

    /// The user cancelled the capture operation.
    case userCancelled
}
