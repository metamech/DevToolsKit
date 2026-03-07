# Metrics Store Guide

[< Metrics Guide](../metrics/GUIDE.md) | [Index](../INDEX.md) | [API Reference >](API.md)

> **Module:** `DevToolsKitMetricsStore` — depends on DevToolsKitMetrics (SwiftData is a system framework)
> **Since:** 0.3.0

## Overview

DevToolsKitMetricsStore provides persistent SwiftData-backed metrics storage with an enhanced query facade, automatic rollup/retention, and SwiftUI environment integration. It is an opt-in upgrade from `InMemoryMetricsStorage` for consumers who need historical queries, time-series aggregation, and retention policies.

## Installation

```swift
// Package.swift
.product(name: "DevToolsKitMetricsStore", package: "DevToolsKit")
```

## Quick Setup

```swift
import DevToolsKitMetrics
import DevToolsKitMetricsStore
import Metrics

// Create the full stack (storage + database + retention engine)
let stack = try MetricsStack.create()

// Bootstrap swift-metrics with the persistent storage
MetricsSystem.bootstrap(DevToolsMetricsFactory(storage: stack.storage))

// Start automatic rollups and retention
await stack.retentionEngine.start()
```

For testing, use an in-memory container:

```swift
let stack = try MetricsStack.create(inMemory: true)
```

## Querying with DatabaseQuery

`DatabaseQuery` provides richer filtering than `MetricsQuery`:

```swift
// All HTTP metrics, hourly averages, last 24 hours
let result = stack.database.execute(DatabaseQuery(
    labelFilter: .prefix("http."),
    startDate: Date().addingTimeInterval(-86400),
    timeBucket: .hour,
    aggregation: .avg,
    sortBy: .timeAscending
))

for row in result.rows {
    print("\(row.bucketStart!) — avg: \(row.value)")
}
```

### Label Filters

- `.exact("http.requests")` — exact match
- `.prefix("http.")` — label starts with prefix
- `.contains("latency")` — label contains substring

### Aggregation Functions

`.sum`, `.avg`, `.min`, `.max`, `.count`, `.latest`, `.p50`, `.p95`, `.p99`

### Time Bucketing

`.minute`, `.hour`, `.day`, `.week`, `.custom(TimeInterval)`

### Gap Fill Strategies

When time-bucketing, empty buckets can be filled:

```swift
DatabaseQuery(
    timeBucket: .hour,
    aggregation: .sum,
    gapFill: .zero          // fill gaps with 0
    // gapFill: .carryForward  // fill gaps with last known value
    // gapFill: .none          // omit empty buckets (default)
)
```

### Grouping by Dimension

```swift
// Average latency grouped by HTTP method
let result = stack.database.execute(DatabaseQuery(
    labelFilter: .exact("http.latency"),
    aggregation: .avg,
    groupByDimension: "method"
))
// result.rows[0].dimensionValue == "GET", result.rows[0].value == 125.5
```

## Streaming Updates

```swift
let stream = stack.database.stream(DatabaseQuery(
    labelFilter: .exact("http.requests"),
    timeBucket: .minute,
    aggregation: .count
))

for await result in stream {
    updateChart(result.rows)
}
```

## Metric Discovery

```swift
let httpMetrics = stack.database.discover(prefix: "http.")
for def in httpMetrics {
    print("\(def.label) (\(def.typeRawValue)) — \(def.totalObservations) observations")
}
```

## Rate Calculation

```swift
// Requests per second over the last 5 minutes
let rate = stack.database.rate(label: "http.requests", over: 300)
```

## Retention Policy

The `RetentionEngine` automatically creates rollups and purges old data:

| Preset | Raw TTL | Hourly Rollup TTL | Daily Rollup TTL | Maintenance |
|--------|---------|-------------------|-------------------|-------------|
| `.default` | 7 days | 90 days | 365 days | 15 min |
| `.compact` | 1 day | 30 days | 90 days | 5 min |
| `.development` | 1 hour | 7 days | 30 days | 1 min |

Custom:

```swift
let stack = try MetricsStack.create(
    retentionPolicy: RetentionPolicy(
        rawDataTTL: 3 * 86400,
        hourlyRollupTTL: 60 * 86400,
        dailyRollupTTL: 180 * 86400
    )
)
```

## SwiftUI Environment

```swift
@main struct MyApp: App {
    @State private var stack = try! MetricsStack.create()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .metricsDatabase(stack.database)
        }
    }
}

struct DashboardView: View {
    @Environment(\.metricsDatabase) private var database

    var body: some View {
        // Use database?.execute(...) etc.
    }
}
```

## Integrating with Existing ModelContainer

If your app already uses SwiftData, include the metrics models in your schema:

```swift
let schema = Schema(YourModel.self, /* ... */ + MetricsStack.modelTypes)
let container = try ModelContainer(for: schema)

let storage = PersistentMetricsStorage(modelContainer: container)
let database = MetricsDatabase(storage: storage, modelContainer: container)
let engine = RetentionEngine(modelContainer: container)
```

## Migration from InMemoryMetricsStorage

`PersistentMetricsStorage` conforms to the same `MetricsStorage` protocol, so it's a drop-in replacement:

```swift
// Before
let storage = InMemoryMetricsStorage(maxEntries: 10_000)

// After
let stack = try MetricsStack.create()
let storage = stack.storage  // conforms to MetricsStorage
```
