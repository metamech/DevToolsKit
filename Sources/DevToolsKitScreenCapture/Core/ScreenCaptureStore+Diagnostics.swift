import DevToolsKit
import Foundation

/// Diagnostic data summary for screen captures.
struct ScreenCaptureDigest: Codable, Sendable {
    let totalCount: Int
    let modeBreakdown: [String: Int]
    let totalStorageBytes: Int
    let recentEntries: [ScreenCaptureEntry]
}

/// Diagnostic provider for screen capture store.
///
/// Since 0.5.0
extension ScreenCaptureStore: DiagnosticProvider {
    public var sectionName: String { "screenCaptures" }

    public func collect() async -> any Codable & Sendable {
        var breakdown: [String: Int] = [:]
        for entry in entries {
            breakdown[entry.mode.rawValue, default: 0] += 1
        }

        return ScreenCaptureDigest(
            totalCount: entries.count,
            modeBreakdown: breakdown,
            totalStorageBytes: totalStorageBytes,
            recentEntries: Array(entries.prefix(20))
        )
    }
}
