#if canImport(UIKit) && !os(tvOS) && !os(watchOS)
import UIKit
import Foundation

/// iOS/visionOS screen capture implementation using UIGraphicsImageRenderer.
@MainActor
enum PlatformCapturer {
    static func captureWindow() async throws -> ScreenCaptureResult {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow })
                ?? windowScene.windows.first
        else {
            throw ScreenCaptureError.noWindowAvailable
        }

        let scale = keyWindow.screen.scale
        let renderer = UIGraphicsImageRenderer(bounds: keyWindow.bounds)
        let image = renderer.image { context in
            keyWindow.drawHierarchy(in: keyWindow.bounds, afterScreenUpdates: true)
        }

        guard let pngData = image.pngData() else {
            throw ScreenCaptureError.captureFailed("Failed to encode PNG data")
        }

        return ScreenCaptureResult(
            imageData: pngData,
            size: keyWindow.bounds.size,
            mode: .window,
            displayScale: scale
        )
    }

    static func captureArea() async throws -> ScreenCaptureResult {
        // Area selection on iOS uses a full-screen overlay with drag gesture
        try await withCheckedThrowingContinuation { continuation in
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow })
                    ?? windowScene.windows.first
            else {
                continuation.resume(throwing: ScreenCaptureError.noWindowAvailable)
                return
            }

            let overlay = AreaSelectionOverlayViewController { rect in
                guard let rect else {
                    continuation.resume(throwing: ScreenCaptureError.userCancelled)
                    return
                }

                let scale = keyWindow.screen.scale
                let renderer = UIGraphicsImageRenderer(bounds: keyWindow.bounds)
                let fullImage = renderer.image { context in
                    keyWindow.drawHierarchy(in: keyWindow.bounds, afterScreenUpdates: true)
                }

                guard let cgImage = fullImage.cgImage else {
                    continuation.resume(
                        throwing: ScreenCaptureError.captureFailed("Failed to get CGImage")
                    )
                    return
                }

                // Crop to selected region in pixel coordinates
                let cropRect = CGRect(
                    x: rect.origin.x * scale,
                    y: rect.origin.y * scale,
                    width: rect.width * scale,
                    height: rect.height * scale
                )

                guard let croppedCG = cgImage.cropping(to: cropRect) else {
                    continuation.resume(
                        throwing: ScreenCaptureError.captureFailed("Failed to crop image")
                    )
                    return
                }

                let croppedImage = UIImage(cgImage: croppedCG, scale: scale, orientation: .up)
                guard let pngData = croppedImage.pngData() else {
                    continuation.resume(
                        throwing: ScreenCaptureError.captureFailed("Failed to encode PNG data")
                    )
                    return
                }

                continuation.resume(returning: ScreenCaptureResult(
                    imageData: pngData,
                    size: rect.size,
                    mode: .area,
                    displayScale: scale
                ))
            }

            overlay.modalPresentationStyle = .overFullScreen
            overlay.modalTransitionStyle = .crossDissolve
            keyWindow.rootViewController?.present(overlay, animated: true)
        }
    }

    static func captureFullScreen() async throws -> ScreenCaptureResult {
        // On single-window platforms, full screen == window capture
        try await captureWindow()
    }
}
#endif
