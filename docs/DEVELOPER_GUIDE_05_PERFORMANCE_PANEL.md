# Developer Guide: Performance Panel

The Performance Dashboard displays metric cards grouped by category, fed by your `MetricsProvider` implementation.

## Setup

```swift
devTools.register(PerformancePanel(provider: MyMetricsProvider()))
```

## Implementing MetricsProvider

```swift
struct MyMetricsProvider: MetricsProvider {
    func currentMetrics() async -> [MetricGroup] {
        let memory = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        return [
            MetricGroup(name: "System", metrics: [
                Metric(name: "Memory", value: memory, unit: "GB", color: .blue),
                Metric(name: "CPU Cores", value: Double(ProcessInfo.processInfo.processorCount), unit: "cores", color: .purple)
            ]),
            MetricGroup(name: "Inference", metrics: [
                Metric(name: "Tokens/sec", value: 42.5, unit: "tok/s", color: .green),
                Metric(name: "Latency", value: 23.1, unit: "ms", color: .orange)
            ])
        ]
    }
}
```

## MetricGroup and Metric

- `MetricGroup(name:metrics:)` — A labeled collection of metrics.
- `Metric(name:value:unit:color:)` — A single numeric value with display properties.
- `MetricColor` — `.blue`, `.purple`, `.orange`, `.red`, `.green`, `.gray`.

## Dashboard UI

- Groups displayed vertically with a title heading
- Metrics within a group displayed as horizontal cards
- Manual "Refresh" button calls `currentMetrics()` on each press
- Data loads on panel appear and clears on disappear
