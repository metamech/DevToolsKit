# Metrics API Reference

[< Guide](GUIDE.md) | [Index](../INDEX.md)

> **Source:** `Sources/DevToolsKitMetrics/`
> **Since:** 0.3.0

## MetricEntry

```swift
public struct MetricEntry: Identifiable, Sendable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let label: String
    public let dimensions: [(String, String)]
    public let type: MetricType
    public let value: Double
}
```

Custom `Codable`: dimensions encode as `[{"key": "...", "value": "..."}]`.

## MetricType

```swift
public enum MetricType: String, Codable, Sendable, CaseIterable {
    case counter, floatingPointCounter, meter, recorder, timer
}
```

## MetricIdentifier

```swift
public struct MetricIdentifier: Hashable, Sendable, Codable {
    public let label: String
    public let dimensions: [(String, String)]
    public let type: MetricType
    public init(entry: MetricEntry)  // Convenience
}
```

Equality and hashing sort dimensions before comparing — `[("b","2"),("a","1")]` equals `[("a","1"),("b","2")]`.

## MetricSummary

```swift
public struct MetricSummary: Identifiable, Sendable {
    public let identifier: MetricIdentifier
    public let count: Int, sum: Double, min: Double, max: Double, avg: Double
    public let latest: Double, latestTimestamp: Date
    public let p50: Double?, p95: Double?, p99: Double?
}
```

## MetricsStorage Protocol

```swift
@MainActor
public protocol MetricsStorage: Sendable {
    func record(_ entry: MetricEntry)
    func query(_ query: MetricsQuery) -> [MetricEntry]
    func summary(for identifier: MetricIdentifier) -> MetricSummary?
    func knownMetrics() -> [MetricIdentifier]
    func clear()
    func purge(olderThan date: Date)
    var entryCount: Int { get }
}
```

## InMemoryMetricsStorage

```swift
@MainActor @Observable
public final class InMemoryMetricsStorage: MetricsStorage, Sendable {
    public init(maxEntries: Int = 10_000)
}
```

FIFO eviction when `maxEntries` is exceeded.

## MetricsQuery

```swift
public struct MetricsQuery: Sendable {
    public var label: String?
    public var type: MetricType?
    public var dimensions: [(String, String)]?   // All must be present
    public var startDate: Date?
    public var endDate: Date?
    public var limit: Int?
    public var sort: MetricsQuerySort            // default: .timestampDescending
}

public enum MetricsQuerySort: Sendable {
    case timestampAscending, timestampDescending, valueAscending, valueDescending
}
```

## MetricsAggregation

```swift
public enum MetricsAggregation {
    public static func summarize(_ entries: [MetricEntry], identifier: MetricIdentifier) -> MetricSummary?
    public static func groupByInterval(_ entries: [MetricEntry], interval: TimeInterval) -> [(date: Date, avg: Double, count: Int)]
}
```

## MetricsManager

```swift
@MainActor @Observable
public final class MetricsManager: Sendable {
    public init(storage: any MetricsStorage = InMemoryMetricsStorage())
    public let storage: any MetricsStorage
    public var searchText: String
    public var filterType: MetricType?
    public var filteredMetrics: [MetricIdentifier]   // computed
    public var latestValues: [MetricIdentifier: Double]  // computed
    public var totalEntries: Int                      // computed
    public func clear()
    public func purge(olderThan date: Date)
}
```

Conforms to `DiagnosticProvider` (sectionName: `"metrics"`).

## DevToolsMetricsFactory

```swift
public final class DevToolsMetricsFactory: MetricsFactory, @unchecked Sendable {
    public init(storage: any MetricsStorage)
}
```

Pass to `MetricsSystem.bootstrap(_:)`.

## MetricsPanel

```swift
public struct MetricsPanel: DevToolPanel {
    public let id = "devtools.metrics"       // ⌘⌥I
    public init(metricsManager: MetricsManager)
}
```
