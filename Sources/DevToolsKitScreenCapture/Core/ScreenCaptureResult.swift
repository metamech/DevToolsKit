import Foundation

/// The result of a screen capture operation.
///
/// Contains PNG-encoded image data along with metadata about how
/// and when the capture was taken.
///
/// Since 0.5.0
public struct ScreenCaptureResult: Sendable {
    /// PNG-encoded image data.
    public let imageData: Data

    /// Image dimensions in points.
    public let size: CGSize

    /// The capture mode used.
    public let mode: ScreenCaptureMode

    /// When the capture was taken.
    public let timestamp: Date

    /// Retina scale factor (e.g. 2.0 on Retina displays).
    public let displayScale: CGFloat

    /// - Parameters:
    ///   - imageData: PNG-encoded image data.
    ///   - size: Image dimensions in points.
    ///   - mode: The capture mode used.
    ///   - timestamp: When the capture was taken; defaults to now.
    ///   - displayScale: Retina scale factor; defaults to 1.0.
    public init(
        imageData: Data,
        size: CGSize,
        mode: ScreenCaptureMode,
        timestamp: Date = Date(),
        displayScale: CGFloat = 1.0
    ) {
        self.imageData = imageData
        self.size = size
        self.mode = mode
        self.timestamp = timestamp
        self.displayScale = displayScale
    }
}
