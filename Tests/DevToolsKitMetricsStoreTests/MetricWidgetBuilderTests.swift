import Foundation
import Testing
@testable import DevToolsKitMetricsStore

@Suite("CounterCardWidget")
struct CounterCardWidgetTests {

    @Test("Creates from numeric value")
    func numericValue() {
        let card = CounterCardWidget(title: "Sessions", icon: "terminal", value: 42)
        #expect(card.title == "Sessions")
        #expect(card.icon == "terminal")
        #expect(card.numericValue == 42)
        #expect(card.formattedValue == "42")
    }

    @Test("Creates from formatted value")
    func formattedValue() {
        let card = CounterCardWidget(title: "Cost", icon: "dollarsign", formattedValue: "$1.23")
        #expect(card.formattedValue == "$1.23")
        #expect(card.numericValue == nil)
    }

    @Test("Auto-generates ID from title")
    func autoId() {
        let card = CounterCardWidget(title: "Active Sessions", icon: "terminal", value: 1)
        #expect(card.id == "counter.active-sessions")
    }

    @Test("Custom ID overrides auto")
    func customId() {
        let card = CounterCardWidget(title: "Test", icon: "star", value: 1, id: "custom.id")
        #expect(card.id == "custom.id")
    }
}

@Suite("GaugeWidget")
struct GaugeWidgetTests {

    @Test("Normalized value in 0...1")
    func normalizedValue() {
        let gauge = GaugeWidget(title: "CPU", value: 0.5)
        #expect(gauge.normalizedValue == 0.5)
    }

    @Test("Normalized value with custom range")
    func customRange() {
        let gauge = GaugeWidget(title: "Temp", value: 50, range: 0...100)
        #expect(gauge.normalizedValue == 0.5)
    }

    @Test("Level normal below warning threshold")
    func normalLevel() {
        let gauge = GaugeWidget(title: "Test", value: 0.5)
        #expect(gauge.level == .normal)
    }

    @Test("Level warning at threshold")
    func warningLevel() {
        let gauge = GaugeWidget(title: "Test", value: 0.75)
        #expect(gauge.level == .warning)
    }

    @Test("Level critical at threshold")
    func criticalLevel() {
        let gauge = GaugeWidget(title: "Test", value: 0.95)
        #expect(gauge.level == .critical)
    }

    @Test("Custom thresholds")
    func customThresholds() {
        let gauge = GaugeWidget(
            title: "Test",
            value: 0.5,
            thresholds: GaugeWidget.Thresholds(warning: 0.3, critical: 0.6)
        )
        #expect(gauge.level == .warning)
    }
}

@Suite("TimeSeriesWidget")
struct TimeSeriesWidgetTests {

    @Test("Sorts data points by date")
    func sortsByDate() {
        let now = Date()
        let earlier = now.addingTimeInterval(-3600)
        let series = TimeSeriesWidget(
            title: "Test",
            dataPoints: [
                .init(date: now, value: 2),
                .init(date: earlier, value: 1),
            ]
        )
        #expect(series.dataPoints.first?.value == 1)
        #expect(series.dataPoints.last?.value == 2)
    }

    @Test("Computes min/max/total/average")
    func aggregations() {
        let now = Date()
        let series = TimeSeriesWidget(
            title: "Test",
            dataPoints: [
                .init(date: now, value: 10),
                .init(date: now.addingTimeInterval(60), value: 20),
                .init(date: now.addingTimeInterval(120), value: 30),
            ]
        )
        #expect(series.minValue == 10)
        #expect(series.maxValue == 30)
        #expect(series.totalValue == 60)
        #expect(series.averageValue == 20)
    }

    @Test("Empty series returns zero for aggregations")
    func emptyAggregations() {
        let series = TimeSeriesWidget(title: "Empty", dataPoints: [])
        #expect(series.minValue == 0)
        #expect(series.maxValue == 0)
        #expect(series.totalValue == 0)
        #expect(series.averageValue == 0)
    }

    @Test("Unit is preserved")
    func unitPreserved() {
        let series = TimeSeriesWidget(title: "Test", dataPoints: [], unit: "ms")
        #expect(series.unit == "ms")
    }
}

@Suite("MetricWidgetBuilder")
struct MetricWidgetBuilderTests {

    @Test("Builder creates counter card")
    func builderCounter() {
        let card = MetricWidgetBuilder.counterCard(title: "Test", icon: "star", value: 99)
        #expect(card.numericValue == 99)
    }

    @Test("Builder creates gauge")
    func builderGauge() {
        let gauge = MetricWidgetBuilder.gauge(title: "CPU", value: 0.8)
        #expect(gauge.level == .warning)
    }

    @Test("Builder creates time series")
    func builderTimeSeries() {
        let series = MetricWidgetBuilder.timeSeries(
            title: "Msgs",
            dataPoints: [.init(date: Date(), value: 1)],
            unit: "count"
        )
        #expect(series.dataPoints.count == 1)
        #expect(series.unit == "count")
    }
}
