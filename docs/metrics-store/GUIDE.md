# Metrics Store Guide

[< Metrics Guide](../metrics/GUIDE.md) | [Index](../INDEX.md) | [API Reference >](API.md)

> **Module:** `DevToolsKitMetricsStore` — depends on DevToolsKitMetrics (SwiftData is a system framework)
> **Since:** 0.3.0

## Overview

DevToolsKitMetricsStore provides persistent SwiftData-backed metrics storage with an enhanced query facade, automatic rollup/retention, and SwiftUI environment integration. It is an opt-in upgrade from `InMemoryMetricsStorage` for consumers who need historical queries, time-series aggregation, and retention policies.

Since 0.7.0, all heavy work (flushing, querying, retention maintenance) runs on background actors with dedicated `ModelContext` instances, keeping the main thread free for UI work.

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

// Start automatic rollups and retention (runs on background actor)
stack.retentionEngine.start()
```

For testing, use an in-memory container:

```swift
let stack = try MetricsStack.create(inMemory: true)
```

## Querying with DatabaseQuery

`DatabaseQuery` provides richer filtering than `MetricsQuery`. Since 0.7.0, `execute()` is async:

```swift
// All HTTP metrics, hourly averages, last 24 hours
let result = await stack.database.execute(DatabaseQuery(
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
let result = await stack.database.execute(DatabaseQuery(
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

## Flushing

The `record()` method remains synchronous (it only appends to an in-memory buffer). Flushing to SwiftData is async since 0.7.0 and runs on a background actor:

```swift
// Manual flush (async)
await storage.flushNow()

// Automatic flushing happens on a timer and when batchSize is reached
```

## Retention Policy

The `RetentionEngine` automatically creates rollups and purges old data. Since 0.7.0, all maintenance runs on a background actor — no main thread impact:

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

Manual maintenance cycle (async since 0.7.0):

```swift
await stack.retentionEngine.runMaintenanceCycle()
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
        // Use await database?.execute(...) in .task {} blocks
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

## Migration from 0.6.x to 0.7.0

Add `await` to all calls to the following methods:

```swift
// Before (0.6.x)
storage.flushNow()
let result = database.execute(query)
engine.runMaintenanceCycle()

// After (0.7.0)
await storage.flushNow()
let result = await database.execute(query)
await engine.runMaintenanceCycle()
```

`RetentionEngine` is no longer `@MainActor`-isolated. It can be created and used from any context. The `start()` and `stop()` methods remain synchronous.
