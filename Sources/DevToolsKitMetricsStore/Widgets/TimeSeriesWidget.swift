import Foundation

/// View model for a time series chart widget.
///
/// Contains an ordered sequence of timestamped data points for chart rendering.
///
/// ```swift
/// let series = TimeSeriesWidget(
///     title: "Messages per Day",
///     dataPoints: [
///         .init(date: today, value: 42),
///         .init(date: yesterday, value: 35),
///     ],
///     unit: "messages"
/// )
/// ```
///
/// - Since: 0.9.0
public struct TimeSeriesWidget: Sendable, Equatable, Identifiable {
    public let id: String

    /// The chart title.
    public let title: String

    /// The data points, ordered by date.
    public let dataPoints: [DataPoint]

    /// Optional unit label (e.g., "messages", "ms", "$").
    public let unit: String?

    /// Creates a time series widget.
    public init(
        title: String,
        dataPoints: [DataPoint],
        unit: String? = nil,
        id: String? = nil
    ) {
        self.id = id ?? "timeseries.\(title.lowercased().replacingOccurrences(of: " ", with: "-"))"
        self.title = title
        self.dataPoints = dataPoints.sorted { $0.date < $1.date }
        self.unit = unit
    }

    /// A single data point in the time series.
    public struct DataPoint: Sendable, Equatable {
        /// The timestamp.
        public let date: Date
        /// The value at this timestamp.
        public let value: Double
        /// Optional label for this point.
        public let label: String?

        public init(date: Date, value: Double, label: String? = nil) {
            self.date = date
            self.value = value
            self.label = label
        }
    }

    /// The minimum value in the series, or 0 if empty.
    public var minValue: Double {
        dataPoints.map(\.value).min() ?? 0
    }

    /// The maximum value in the series, or 0 if empty.
    public var maxValue: Double {
        dataPoints.map(\.value).max() ?? 0
    }

    /// The sum of all values in the series.
    public var totalValue: Double {
        dataPoints.reduce(0) { $0 + $1.value }
    }

    /// The average value, or 0 if empty.
    public var averageValue: Double {
        guard !dataPoints.isEmpty else { return 0 }
        return totalValue / Double(dataPoints.count)
    }
}
