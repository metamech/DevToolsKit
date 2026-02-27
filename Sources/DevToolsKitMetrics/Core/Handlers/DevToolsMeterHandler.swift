import CoreMetrics
import Foundation

/// swift-metrics meter handler that records values to a ``MetricsStorage``.
final class DevToolsMeterHandler: MeterHandler, @unchecked Sendable {
    private let label: String
    private let dimensions: [(String, String)]
    private let storage: any MetricsStorage

    init(label: String, dimensions: [(String, String)], storage: any MetricsStorage) {
        self.label = label
        self.dimensions = dimensions
        self.storage = storage
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
        Task { @MainActor in
            storage.record(entry)
        }
    }
}
