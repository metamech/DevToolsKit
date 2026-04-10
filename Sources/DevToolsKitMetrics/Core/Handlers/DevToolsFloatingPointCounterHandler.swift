import CoreMetrics
import Foundation

/// swift-metrics floating point counter handler that records increments to a ``MetricsStorage``.
final class DevToolsFloatingPointCounterHandler: FloatingPointCounterHandler, @unchecked Sendable {
    private let label: String
    private let dimensions: [(String, String)]
    private let batcher: MetricsBatcher

    init(label: String, dimensions: [(String, String)], batcher: MetricsBatcher) {
        self.label = label
        self.dimensions = dimensions
        self.batcher = batcher
    }

    func increment(by amount: Double) {
        let entry = MetricEntry(
            label: label,
            dimensions: dimensions,
            type: .floatingPointCounter,
            value: amount
        )
        batcher.append(entry)
    }

    func reset() {}
}
