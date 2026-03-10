#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import Foundation

/// Utilities for exporting screen capture results to files or clipboard.
///
/// Since 0.5.0
public enum ScreenCaptureExporter: Sendable {
    /// Copy image data to the system clipboard.
    ///
    /// - Parameter result: The capture result to copy.
    /// - Throws: ``ScreenCaptureError`` if the platform does not support clipboard access.
    @MainActor
    public static func copyToClipboard(_ result: ScreenCaptureResult) throws {
        #if canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard let image = NSImage(data: result.imageData) else {
            throw ScreenCaptureError.captureFailed("Failed to create image from data")
        }
        pasteboard.writeObjects([image])
        #elseif canImport(UIKit) && !os(tvOS) && !os(watchOS)
        guard let image = UIImage(data: result.imageData) else {
            throw ScreenCaptureError.captureFailed("Failed to create image from data")
        }
        UIPasteboard.general.image = image
        #else
        throw ScreenCaptureError.unsupportedPlatform
        #endif
    }

    /// Save a capture result to a file in the specified format.
    ///
    /// - Parameters:
    ///   - result: The capture result to save.
    ///   - url: The file URL to write to.
    ///   - format: The image format; defaults to PNG.
    /// - Throws: If format conversion or file writing fails.
    public static func save(
        _ result: ScreenCaptureResult,
        to url: URL,
        format: ScreenCaptureFormat = .png
    ) throws {
        let outputData = try data(from: result, format: format)
        try outputData.write(to: url, options: .atomic)
    }

    /// Convert a capture result to the specified image format.
    ///
    /// - Parameters:
    ///   - result: The capture result to convert.
    ///   - format: The target image format.
    /// - Returns: The image data in the requested format.
    /// - Throws: If format conversion fails.
    public static func data(
        from result: ScreenCaptureResult,
        format: ScreenCaptureFormat
    ) throws -> Data {
        switch format {
        case .png:
            return result.imageData  // Already PNG

        case .jpeg, .tiff:
            #if canImport(AppKit)
            guard let bitmapRep = NSBitmapImageRep(data: result.imageData) else {
                throw ScreenCaptureError.captureFailed("Failed to create bitmap representation")
            }
            let fileType: NSBitmapImageRep.FileType = format == .jpeg ? .jpeg : .tiff
            let properties: [NSBitmapImageRep.PropertyKey: Any] = format == .jpeg
                ? [.compressionFactor: 0.85]
                : [:]
            guard let data = bitmapRep.representation(using: fileType, properties: properties) else {
                throw ScreenCaptureError.captureFailed("Failed to convert to \(format.rawValue)")
            }
            return data
            #elseif canImport(UIKit)
            guard let image = UIImage(data: result.imageData) else {
                throw ScreenCaptureError.captureFailed("Failed to create UIImage from data")
            }
            if format == .jpeg {
                guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
                    throw ScreenCaptureError.captureFailed("Failed to convert to JPEG")
                }
                return jpegData
            }
            // TIFF not natively supported on UIKit; return PNG as fallback
            return result.imageData
            #else
            throw ScreenCaptureError.unsupportedPlatform
            #endif
        }
    }
}
