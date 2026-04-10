import CoreMetrics
import Foundation

/// swift-metrics timer handler that records nanosecond durations to a ``MetricsStorage``.
final class DevToolsTimerHandler: TimerHandler, @unchecked Sendable {
    private let label: String
    private let dimensions: [(String, String)]
    private let batcher: MetricsBatcher

    init(label: String, dimensions: [(String, String)], batcher: MetricsBatcher) {
        self.label = label
        self.dimensions = dimensions
        self.batcher = batcher
    }

    func recordNanoseconds(_ duration: Int64) {
        let entry = MetricEntry(
            label: label,
            dimensions: dimensions,
            type: .timer,
            value: Double(duration)
        )
        batcher.append(entry)
    }
}
