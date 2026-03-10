import DevToolsKit
import Foundation

/// Diagnostic data summary for issue captures (without screenshot data).
struct IssueCaptureDigest: Codable, Sendable {
    let totalCaptures: Int
    let providerCounts: [String: Int]
    let tagCounts: [String: Int]
    let recentCaptures: [CaptureDigest]

    struct CaptureDigest: Codable, Sendable {
        let id: String
        let timestamp: Date
        let providerID: String
        let capturedState: [String: String]
        let expectedState: [String: String]
        let tags: [String]
    }
}

extension IssueCaptureStore: DiagnosticProvider {
    public var sectionName: String { "issueCaptures" }

    public func collect() async -> any Codable & Sendable {
        let providerCounts = Dictionary(grouping: captures, by: \.providerID)
            .mapValues(\.count)
        let tagCounts: [String: Int] = captures
            .flatMap(\.tags)
            .reduce(into: [:]) { $0[$1, default: 0] += 1 }

        let recent = captures.prefix(20).map { capture in
            IssueCaptureDigest.CaptureDigest(
                id: capture.id.uuidString,
                timestamp: capture.timestamp,
                providerID: capture.providerID,
                capturedState: capture.capturedState,
                expectedState: capture.expectedState,
                tags: capture.tags
            )
        }

        return IssueCaptureDigest(
            totalCaptures: captures.count,
            providerCounts: providerCounts,
            tagCounts: tagCounts,
            recentCaptures: recent
        )
    }
}
