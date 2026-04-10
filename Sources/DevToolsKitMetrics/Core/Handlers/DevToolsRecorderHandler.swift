import CoreMetrics
import Foundation

/// swift-metrics recorder handler that records values to a ``MetricsStorage``.
final class DevToolsRecorderHandler: RecorderHandler, @unchecked Sendable {
    private let label: String
    private let dimensions: [(String, String)]
    private let batcher: MetricsBatcher

    init(label: String, dimensions: [(String, String)], batcher: MetricsBatcher) {
        self.label = label
        self.dimensions = dimensions
        self.batcher = batcher
    }

    func record(_ value: Int64) {
        record(Double(value))
    }

    func record(_ value: Double) {
        let entry = MetricEntry(
            label: label,
            dimensions: dimensions,
            type: .recorder,
            value: value
        )
        batcher.append(entry)
    }
}
