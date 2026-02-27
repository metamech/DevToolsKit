import CoreMetrics
import Foundation

/// swift-metrics recorder handler that records values to a ``MetricsStorage``.
final class DevToolsRecorderHandler: RecorderHandler, @unchecked Sendable {
    private let label: String
    private let dimensions: [(String, String)]
    private let storage: any MetricsStorage

    init(label: String, dimensions: [(String, String)], storage: any MetricsStorage) {
        self.label = label
        self.dimensions = dimensions
        self.storage = storage
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
        Task { @MainActor in
            storage.record(entry)
        }
    }
}
