/// Output format for exported screen captures.
///
/// Since 0.5.0
public enum ScreenCaptureFormat: String, Sendable, CaseIterable {
    /// Portable Network Graphics — lossless, supports transparency.
    case png

    /// JPEG — lossy compression, smaller file size.
    case jpeg

    /// Tagged Image File Format — lossless, large file size.
    case tiff
}
