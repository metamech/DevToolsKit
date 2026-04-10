import CoreMetrics
import Foundation

/// swift-metrics meter handler that records values to a ``MetricsStorage``.
final class DevToolsMeterHandler: MeterHandler, @unchecked Sendable {
    private let label: String
    private let dimensions: [(String, String)]
    private let batcher: MetricsBatcher

    init(label: String, dimensions: [(String, String)], batcher: MetricsBatcher) {
        self.label = label
        self.dimensions = dimensions
        self.batcher = batcher
    }

    func set(_ value: Int64) {
        record(Double(value))
    }

    func set(_ value: Double) {
        record(value)
    }

    func increment(by amount: Double) {
        record(amount)
    }

    func decrement(by amount: Double) {
        record(-amount)
    }

    private func record(_ value: Double) {
        let entry = MetricEntry(
            label: label,
            dimensions: dimensions,
            type: .meter,
            value: value
        )
        batcher.append(entry)
    }
}
