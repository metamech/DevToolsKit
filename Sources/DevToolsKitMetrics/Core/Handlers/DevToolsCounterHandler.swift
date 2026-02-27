import CoreMetrics
import Foundation

/// swift-metrics counter handler that records increments to a ``MetricsStorage``.
final class DevToolsCounterHandler: CounterHandler, @unchecked Sendable {
    private let label: String
    private let dimensions: [(String, String)]
    private let storage: any MetricsStorage

    init(label: String, dimensions: [(String, String)], storage: any MetricsStorage) {
        self.label = label
        self.dimensions = dimensions
        self.storage = storage
    }

    func increment(by amount: Int64) {
        let entry = MetricEntry(
            label: label,
            dimensions: dimensions,
            type: .counter,
            value: Double(amount)
        )
        Task { @MainActor in
            storage.record(entry)
        }
    }

    func reset() {}
}
