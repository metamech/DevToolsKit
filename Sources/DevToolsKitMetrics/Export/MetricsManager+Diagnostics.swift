import DevToolsKit
import Foundation

extension MetricsManager: DiagnosticProvider {
    public var sectionName: String { "metrics" }

    public func collect() async -> any Codable & Sendable {
        let metrics = storage.knownMetrics()
        var summaries: [MetricDiagnosticEntry] = []

        for identifier in metrics {
            if let summary = storage.summary(for: identifier) {
                summaries.append(
                    MetricDiagnosticEntry(
                        label: identifier.label,
                        type: identifier.type.rawValue,
                        count: summary.count,
                        latest: summary.latest,
                        avg: summary.avg,
                        min: summary.min,
                        max: summary.max
                    )
                )
            }
        }

        return summaries
    }
}

/// Codable representation of a metric summary for diagnostic export.
struct MetricDiagnosticEntry: Codable, Sendable {
    let label: String
    let type: String
    let count: Int
    let latest: Double
    let avg: Double
    let min: Double
    let max: Double
}
