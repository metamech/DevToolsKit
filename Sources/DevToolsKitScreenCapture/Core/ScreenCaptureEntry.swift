import Foundation

/// Persisted metadata model for a screen capture.
///
/// Since 0.5.0
public struct ScreenCaptureEntry: Codable, Sendable, Identifiable {
    /// Unique identifier for this capture entry.
    public let id: UUID

    /// When the capture was taken.
    public let timestamp: Date

    /// The capture mode used (window, area, or full screen).
    public let mode: ScreenCaptureMode

    /// The pixel dimensions of the captured image.
    public let imageSize: CGSize

    /// The display scale factor at capture time.
    public let displayScale: CGFloat

    /// The size of the image data in bytes.
    public let imageDataSize: Int

    /// Creates a new screen capture entry with explicit values.
    public init(
        id: UUID = UUID(),
        timestamp: Date,
        mode: ScreenCaptureMode,
        imageSize: CGSize,
        displayScale: CGFloat,
        imageDataSize: Int
    ) {
        self.id = id
        self.timestamp = timestamp
        self.mode = mode
        self.imageSize = imageSize
        self.displayScale = displayScale
        self.imageDataSize = imageDataSize
    }

    /// Creates a screen capture entry by extracting metadata from a capture result.
    public init(result: ScreenCaptureResult) {
        self.id = UUID()
        self.timestamp = result.timestamp
        self.mode = result.mode
        self.imageSize = result.size
        self.displayScale = result.displayScale
        self.imageDataSize = result.imageData.count
    }
}
