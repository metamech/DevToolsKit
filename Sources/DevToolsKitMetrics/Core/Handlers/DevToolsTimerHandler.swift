import CoreMetrics
import Foundation

/// swift-metrics timer handler that records nanosecond durations to a ``MetricsStorage``.
final class DevToolsTimerHandler: TimerHandler, @unchecked Sendable {
    private let label: String
    private let dimensions: [(String, String)]
    private let storage: any MetricsStorage

    init(label: String, dimensions: [(String, String)], storage: any MetricsStorage) {
        self.label = label
        self.dimensions = dimensions
        self.storage = storage
    }

    func recordNanoseconds(_ duration: Int64) {
        let entry = MetricEntry(
            label: label,
            dimensions: dimensions,
            type: .timer,
            value: Double(duration)
        )
        Task { @MainActor in
            storage.record(entry)
        }
    }
}
