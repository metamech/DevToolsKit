import Foundation

/// View model for a gauge widget.
///
/// Represents a value within a range, with threshold levels for visual indicators.
///
/// ```swift
/// let gauge = GaugeWidget(
///     title: "Context Usage",
///     value: 0.75,
///     thresholds: GaugeWidget.Thresholds(warning: 0.7, critical: 0.9)
/// )
/// print(gauge.level) // .warning
/// ```
///
/// - Since: 0.9.0
public struct GaugeWidget: Sendable, Equatable, Identifiable {
    public let id: String

    /// The gauge title.
    public let title: String

    /// The current value.
    public let value: Double

    /// The valid range for the gauge.
    public let range: ClosedRange<Double>

    /// Threshold definitions for visual levels.
    public let thresholds: Thresholds

    /// Creates a gauge widget.
    public init(
        title: String,
        value: Double,
        range: ClosedRange<Double> = 0...1,
        thresholds: Thresholds = .default,
        id: String? = nil
    ) {
        self.id = id ?? "gauge.\(title.lowercased().replacingOccurrences(of: " ", with: "-"))"
        self.title = title
        self.value = value
        self.range = range
        self.thresholds = thresholds
    }

    /// The normalized value (0...1) within the range.
    public var normalizedValue: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return max(0, min(1, (value - range.lowerBound) / span))
    }

    /// The current severity level based on thresholds.
    public var level: Level {
        if normalizedValue >= thresholds.critical { return .critical }
        if normalizedValue >= thresholds.warning { return .warning }
        return .normal
    }

    /// Severity levels for gauge visualization.
    public enum Level: String, Sendable {
        case normal
        case warning
        case critical
    }

    /// Threshold values for gauge levels.
    public struct Thresholds: Sendable, Equatable {
        /// Normalized value at which the gauge enters warning state.
        public let warning: Double
        /// Normalized value at which the gauge enters critical state.
        public let critical: Double

        public init(warning: Double = 0.7, critical: Double = 0.9) {
            self.warning = warning
            self.critical = critical
        }

        /// Default thresholds: warning at 70%, critical at 90%.
        public static let `default` = Thresholds()
    }
}
