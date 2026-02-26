import Foundation

/// A named group of metrics for the performance dashboard.
public struct MetricGroup: Sendable {
    public let name: String
    public let metrics: [Metric]

    public init(name: String, metrics: [Metric]) {
        self.name = name
        self.metrics = metrics
    }
}

/// A single named metric value.
public struct Metric: Sendable {
    public let name: String
    public let value: Double
    public let unit: String
    public let color: MetricColor

    public init(name: String, value: Double, unit: String, color: MetricColor = .blue) {
        self.name = name
        self.value = value
        self.unit = unit
        self.color = color
    }
}

/// Color hint for metric display.
public enum MetricColor: String, Sendable {
    case blue, purple, orange, red, green, gray
}

/// Protocol for providing metrics to the performance dashboard.
///
/// Implement this to supply your app's performance data.
@MainActor
public protocol MetricsProvider: Sendable {
    /// Collect current metric groups.
    func currentMetrics() async -> [MetricGroup]
}
