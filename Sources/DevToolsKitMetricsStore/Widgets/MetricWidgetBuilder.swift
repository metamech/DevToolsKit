import Foundation

/// Builder for creating metric widget view models from query results.
///
/// Provides a declarative API for transforming ``QueryResult`` data into
/// widget-ready view models for common dashboard patterns.
///
/// ```swift
/// let widget = MetricWidgetBuilder.counterCard(
///     title: "Active Sessions",
///     icon: "terminal",
///     value: 5
/// )
/// ```
///
/// - Since: 0.9.0
public enum MetricWidgetBuilder {

    /// Creates a counter card widget from a static value.
    public static func counterCard(
        title: String,
        icon: String,
        value: Int,
        subtitle: String? = nil
    ) -> CounterCardWidget {
        CounterCardWidget(title: title, icon: icon, value: value, subtitle: subtitle)
    }

    /// Creates a counter card from a formatted string value.
    public static func counterCard(
        title: String,
        icon: String,
        formattedValue: String,
        subtitle: String? = nil
    ) -> CounterCardWidget {
        CounterCardWidget(title: title, icon: icon, formattedValue: formattedValue, subtitle: subtitle)
    }

    /// Creates a gauge widget.
    public static func gauge(
        title: String,
        value: Double,
        range: ClosedRange<Double> = 0...1,
        thresholds: GaugeWidget.Thresholds = .default
    ) -> GaugeWidget {
        GaugeWidget(title: title, value: value, range: range, thresholds: thresholds)
    }

    /// Creates a time series widget from data points.
    public static func timeSeries(
        title: String,
        dataPoints: [TimeSeriesWidget.DataPoint],
        unit: String? = nil
    ) -> TimeSeriesWidget {
        TimeSeriesWidget(title: title, dataPoints: dataPoints, unit: unit)
    }
}
