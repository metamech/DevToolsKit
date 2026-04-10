import CoreMetrics
import Foundation

/// swift-metrics counter handler that records increments to a ``MetricsStorage``.
final class DevToolsCounterHandler: CounterHandler, @unchecked Sendable {
    private let label: String
    private let dimensions: [(String, String)]
    private let batcher: MetricsBatcher

    init(label: String, dimensions: [(String, String)], batcher: MetricsBatcher) {
        self.label = label
        self.dimensions = dimensions
        self.batcher = batcher
    }

    func increment(by amount: Int64) {
        let entry = MetricEntry(
            label: label,
            dimensions: dimensions,
            type: .counter,
            value: Double(amount)
        )
        batcher.append(entry)
    }

    func reset() {}
}
