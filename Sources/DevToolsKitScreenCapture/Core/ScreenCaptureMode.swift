/// How a screen capture should be performed.
///
/// Since 0.5.0
public enum ScreenCaptureMode: String, Codable, Sendable, CaseIterable {
    /// Capture a specific window.
    case window

    /// User-drawn region selection.
    case area

    /// Entire screen or display.
    case fullScreen
}
