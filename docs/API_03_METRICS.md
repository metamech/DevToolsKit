[< Logging](API_02_LOGGING.md) | [Index](API_00_OVERVIEW.md) | [Inspector & Environment >](API_04_INSPECTOR_ENVIRONMENT.md)

# API Reference: Metrics

> Source: `Sources/DevToolsKit/Panels/PerformancePanel/`

## MetricsProvider

```swift
@MainActor
public protocol MetricsProvider: Sendable {
    func currentMetrics() async -> [MetricGroup]
}
```

Implement this protocol to supply performance data to the dashboard. Called on each manual refresh.

## MetricGroup

```swift
public struct MetricGroup: Sendable {
    public let name: String
    public let metrics: [Metric]

    public init(name: String, metrics: [Metric])
}
```

A named collection of metrics displayed as a section in the dashboard.

## Metric

```swift
public struct Metric: Sendable {
    public let name: String
    public let value: Double
    public let unit: String
    public let color: MetricColor

    public init(name: String, value: Double, unit: String, color: MetricColor = .blue)
}
```

A single numeric metric displayed as a card.

## MetricColor

```swift
public enum MetricColor: String, Sendable {
    case blue, purple, orange, red, green, gray
}
```

Color hint for metric card display.

## PerformancePanel

```swift
public struct PerformancePanel: DevToolPanel {
    public let id = "devtools.performance"
    public let title = "Performance"
    public let icon = "gauge"
    public let keyboardShortcut = DevToolsKeyboardShortcut(key: "m")  // ⌘⌥M

    public init(provider: any MetricsProvider)
    public func makeBody() -> AnyView
}
```

## PerformancePanelView

```swift
public struct PerformancePanelView: View {
    public init(provider: any MetricsProvider)
    public var body: some View
}
```

Metric card grid with manual refresh button. Loads data on appear.

---

[< Logging](API_02_LOGGING.md) | [Index](API_00_OVERVIEW.md) | [Inspector & Environment >](API_04_INSPECTOR_ENVIRONMENT.md)
