import Foundation

/// A named group of metrics for the performance dashboard.
public struct MetricGroup: Sendable {
    /// Display name for this group (e.g., "Inference", "Network").
    public let name: String
    /// The metrics in this group.
    public let metrics: [Metric]

    /// - Parameters:
    ///   - name: Display name for this group.
    ///   - metrics: The metrics to display.
    public init(name: String, metrics: [Metric]) {
        self.name = name
        self.metrics = metrics
    }
}

/// A single named metric value displayed as a card in the performance dashboard.
public struct Metric: Sendable {
    /// Display name (e.g., "Tokens/sec").
    public let name: String
    /// Numeric value.
    public let value: Double
    /// Unit label (e.g., "ms", "MB", "tok/s").
    public let unit: String
    /// Color hint for the metric card.
    public let color: MetricColor

    /// - Parameters:
    ///   - name: Display name for the metric.
    ///   - value: Numeric value.
    ///   - unit: Unit label shown below the value.
    ///   - color: Color hint; defaults to `.blue`.
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
/// Implement this to supply your app's performance data:
///
/// ```swift
/// struct MyMetrics: MetricsProvider {
///     func currentMetrics() async -> [MetricGroup] {
///         [MetricGroup(name: "Inference", metrics: [
///             Metric(name: "Tokens/sec", value: 42.5, unit: "tok/s", color: .green)
///         ])]
///     }
/// }
/// ```
@MainActor
public protocol MetricsProvider: Sendable {
    /// Collect current metric groups. Called on each manual refresh.
    func currentMetrics() async -> [MetricGroup]
}
