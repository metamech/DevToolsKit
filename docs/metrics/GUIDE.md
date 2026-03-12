# Metrics Integration Guide

[Index](../INDEX.md) | [API Reference >](API.md)

> **Module:** `DevToolsKitMetrics` — depends on DevToolsKit + [swift-metrics](https://github.com/apple/swift-metrics)
> **Since:** 0.3.0

## Overview

DevToolsKitMetrics captures the raw swift-metrics stream into pluggable storage, providing query, aggregation, and a panel UI for deep metric inspection. It is complementary to the core `PerformancePanel` — use `PerformancePanel` for a curated dashboard, and `MetricsPanel` for the full metric firehose.

## Installation

```swift
// Package.swift
.product(name: "DevToolsKitMetrics", package: "DevToolsKit")
```

## Setup

```swift
import DevToolsKit
import DevToolsKitMetrics
import Metrics

let metricsStore = InMemoryMetricsStorage(maxEntries: 10_000)
let metricsManager = MetricsManager(storage: metricsStore)

// Bootstrap swift-metrics
MetricsSystem.bootstrap(DevToolsMetricsFactory(storage: metricsStore))

// Register the metrics inspector panel
manager.register(MetricsPanel(metricsManager: metricsManager))

// Optional: include metrics in diagnostic export
manager.registerDiagnosticProvider(metricsManager)
```

## Usage

Once bootstrapped, all standard swift-metrics calls are captured automatically:

```swift
Counter(label: "http.requests", dimensions: [("method", "GET")]).increment()
Timer(label: "http.latency", dimensions: [("path", "/api")]).recordNanoseconds(1_500_000)
Gauge(label: "memory.used").record(512.0)
```

## Metrics Panel (⌘⌥I)

Three tabs:

### Live Tab
Real-time list of all known metrics grouped by label prefix (e.g., `http.`, `db.`). Shows latest value for each metric. Click a metric to see its detail view with:
- Summary stats (count, avg, min, max, p50, p95, p99)
- Sparkline chart of recent values
- Scrollable entry list

### Query Tab
Filter entries by label, type, date range, and limit. Results displayed in a sortable table.

### Report Tab
Summary statistics table showing all known metrics with count, avg, min, max, and percentiles.

## Querying Metrics Programmatically

```swift
// All counter entries from the last hour
let results = metricsStore.query(MetricsQuery(
    type: .counter,
    startDate: Date().addingTimeInterval(-3600),
    sort: .timestampDescending,
    limit: 100
))

// Summary for a specific metric
let id = MetricIdentifier(label: "http.latency", dimensions: [], type: .timer)
let summary = metricsStore.summary(for: id)
// summary.avg, summary.p95, summary.count, etc.
```

## Time-Series Aggregation

Group entries by time interval for charting:

```swift
let buckets = MetricsAggregation.groupByInterval(entries, interval: 60)
// Returns [(date: Date, avg: Double, count: Int)] sorted by date
```

## Supported Metric Types

| swift-metrics Type | `MetricType` | Handler |
|-------------------|--------------|---------|
| `Counter` | `.counter` | Records Int64 increments |
| `FloatingPointCounter` | `.floatingPointCounter` | Records Double increments |
| `Gauge` (Meter) | `.meter` | Records set/increment/decrement |
| `Recorder` | `.recorder` | Records Int64/Double values |
| `Timer` | `.timer` | Records nanosecond durations |

## Storage

`InMemoryMetricsStorage` is a FIFO ring buffer. When `maxEntries` is exceeded, oldest entries are evicted. For persistent storage with SwiftData, time-series aggregation, rollups, and retention policies, see [DevToolsKitMetricsStore](../metrics-store/GUIDE.md). To implement a custom storage backend, conform to `MetricsStorage`.

## Performance (Since 0.6.0)

`InMemoryMetricsStorage` maintains a per-identifier index internally, making `summary(for:)` O(K) where K is the number of entries for that metric (instead of scanning all N entries). A `latestValue(for:)` method provides O(1) lookup for the most recent value of any metric.

The Metrics Live tab and Detail view load data asynchronously, so even with 10k+ entries the UI never blocks. Custom `MetricsStorage` implementations can override `latestValue(for:)` for optimized lookups; the default falls back to `summary(for:)?.latest`.
