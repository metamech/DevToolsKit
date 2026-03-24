# Metrics Store API Reference

[< Guide](GUIDE.md) | [Index](../INDEX.md)

> **Module:** `DevToolsKitMetricsStore`
> **Source:** `Sources/DevToolsKitMetricsStore/`
> **Since:** 0.3.0

## Models

### MetricObservation

> Source: `Sources/DevToolsKitMetricsStore/Models/MetricObservation.swift`

```swift
@Model
public final class MetricObservation {
    public var observationID: UUID
    public var timestamp: Date
    public var label: String
    public var typeRawValue: String
    public var value: Double
    public var dimensionsKey: String
    @Relationship(deleteRule: .cascade, inverse: \MetricDimension.observation)
    public var dimensions: [MetricDimension]

    public convenience init(entry: MetricEntry)
    public func toMetricEntry() -> MetricEntry
}
```

### MetricDimension

> Source: `Sources/DevToolsKitMetricsStore/Models/MetricDimension.swift`

```swift
@Model
public final class MetricDimension {
    public var key: String
    public var value: String
    public var observation: MetricObservation?
}
```

### MetricRollup

> Source: `Sources/DevToolsKitMetricsStore/Models/MetricRollup.swift`

```swift
@Model
public final class MetricRollup {
    public var label: String
    public var typeRawValue: String
    public var dimensionsKey: String
    public var granularity: String  // "hourly" or "daily"
    public var bucketStart: Date
    public var bucketEnd: Date
    public var count: Int
    public var sum: Double
    public var min: Double
    public var max: Double
    public var avg: Double
}
```

### MetricDefinition

> Source: `Sources/DevToolsKitMetricsStore/Models/MetricDefinition.swift`

```swift
@Model
public final class MetricDefinition {
    public var label: String
    public var typeRawValue: String
    public var knownDimensionKeysJSON: String
    public var firstSeenAt: Date
    public var lastSeenAt: Date
    public var totalObservations: Int
}
```

### MetricsModelTypes

> Source: `Sources/DevToolsKitMetricsStore/Models/MetricsModelTypes.swift`

```swift
public enum MetricsModelTypes {
    public static var all: [any PersistentModel.Type]
}
```

## Storage

### PersistentMetricsStorage

> Source: `Sources/DevToolsKitMetricsStore/Storage/PersistentMetricsStorage.swift`

```swift
@MainActor @Observable
public final class PersistentMetricsStorage: MetricsStorage, Sendable {
    public init(modelContainer: ModelContainer, batchSize: Int = 50, flushInterval: TimeInterval = 1.0)

    /// Force-flush the current buffer to persistent storage.
    /// Since 0.7.0: now `async` — flush work runs on a background actor.
    public func flushNow() async

    // MetricsStorage conformance
    public func record(_ entry: MetricEntry)
    public func query(_ query: MetricsQuery) -> [MetricEntry]
    public func summary(for identifier: MetricIdentifier) -> MetricSummary?
    public func knownMetrics() -> [MetricIdentifier]
    public func clear()
    public func purge(olderThan date: Date)
    public var entryCount: Int { get }
}
```

## Query Types

### DatabaseQuery

> Source: `Sources/DevToolsKitMetricsStore/Query/DatabaseQuery.swift`

```swift
public struct DatabaseQuery: Sendable {
    public var labelFilter: LabelFilter?
    public var typeFilter: MetricType?
    public var dimensionFilters: [(String, String)]?
    public var startDate: Date?
    public var endDate: Date?
    public var timeBucket: TimeBucket?
    public var aggregation: AggregationFunction?
    public var groupByDimension: String?
    public var gapFill: GapFillStrategy       // default: .none
    public var preferRollups: Bool             // default: true
    public var limit: Int?
    public var sortBy: ResultSort              // default: .timeDescending
}
```

### LabelFilter

```swift
public enum LabelFilter: Sendable {
    case exact(String)
    case prefix(String)
    case contains(String)
}
```

### TimeBucket

```swift
public enum TimeBucket: Sendable {
    case minute, hour, day, week
    case custom(TimeInterval)
    public var interval: TimeInterval { get }
}
```

### AggregationFunction

```swift
public enum AggregationFunction: Sendable {
    case sum, avg, min, max, count, latest, p50, p95, p99
}
```

### GapFillStrategy

```swift
public enum GapFillStrategy: Sendable {
    case none, zero, carryForward
}
```

### ResultSort

```swift
public enum ResultSort: Sendable {
    case valueAscending, valueDescending, labelAscending, timeAscending, timeDescending
}
```

### QueryResult / QueryResultRow

```swift
public struct QueryResult: Sendable {
    public let rows: [QueryResultRow]
    public let computedAt: Date
    public let observationsScanned: Int
}

public struct QueryResultRow: Identifiable, Sendable {
    public let id: UUID
    public let label: String
    public let dimensionValue: String?
    public let bucketStart: Date?
    public let value: Double
    public let count: Int
}
```

## Database

### MetricsDatabase

> Source: `Sources/DevToolsKitMetricsStore/Database/MetricsDatabase.swift`

```swift
@MainActor @Observable
public final class MetricsDatabase: Sendable {
    public init(storage: PersistentMetricsStorage, modelContainer: ModelContainer)

    /// Execute a query. Since 0.7.0: now `async` — runs on a background ModelContext.
    public func execute(_ query: DatabaseQuery) async -> QueryResult

    public func stream(_ query: DatabaseQuery) -> AsyncStream<QueryResult>
    public func discover(prefix: String? = nil) -> [MetricDefinition]
    public func summary(for label: String, type: MetricType? = nil) -> MetricSummary?
    public func rate(label: String, over interval: TimeInterval) -> Double?
}
```

### SwiftUI Environment

```swift
extension EnvironmentValues {
    @Entry public var metricsDatabase: MetricsDatabase?
}

extension View {
    public func metricsDatabase(_ database: MetricsDatabase) -> some View
}
```

## Retention

### RetentionPolicy

> Source: `Sources/DevToolsKitMetricsStore/Retention/RetentionPolicy.swift`

```swift
public struct RetentionPolicy: Sendable {
    public var rawDataTTL: TimeInterval          // default: 7 days
    public var hourlyRollupTTL: TimeInterval     // default: 90 days
    public var dailyRollupTTL: TimeInterval      // default: 365 days
    public var maintenanceInterval: TimeInterval  // default: 15 min

    public static let `default`: RetentionPolicy
    public static let compact: RetentionPolicy
    public static let development: RetentionPolicy
}
```

### RetentionEngine

> Source: `Sources/DevToolsKitMetricsStore/Retention/RetentionEngine.swift`

```swift
/// Since 0.7.0: no longer `@MainActor`. Maintenance runs on a background actor.
public final class RetentionEngine: Sendable {
    public init(modelContainer: ModelContainer, policy: RetentionPolicy = .default)
    public func start()
    public func stop()

    /// Since 0.7.0: now `async`. Delegates to a background MaintenanceWorker actor.
    public func runMaintenanceCycle() async
}
```

## MetricsStack

> Source: `Sources/DevToolsKitMetricsStore/MetricsStack.swift`

```swift
@MainActor
public struct MetricsStack: Sendable {
    public let storage: PersistentMetricsStorage
    public let database: MetricsDatabase
    public let retentionEngine: RetentionEngine
    public let modelContainer: ModelContainer

    public static var modelTypes: [any PersistentModel.Type] { get }
    public static func create(
        inMemory: Bool = false,
        retentionPolicy: RetentionPolicy = .default,
        batchSize: Int = 50
    ) throws -> MetricsStack
}
```

## Notifications

| Name | Posted When |
|------|-------------|
| `.metricsStoreDidFlush` | After each batch flush to persistent storage |

## Breaking Changes in 0.7.0

The following APIs changed from synchronous to `async` to move heavy work off the main thread:

| API | Before (0.6.x) | After (0.7.0) |
|-----|-----------------|---------------|
| `RetentionEngine.runMaintenanceCycle()` | `func runMaintenanceCycle()` | `func runMaintenanceCycle() async` |
| `PersistentMetricsStorage.flushNow()` | `func flushNow()` | `func flushNow() async` |
| `MetricsDatabase.execute(_:)` | `func execute(_ query:) -> QueryResult` | `func execute(_ query:) async -> QueryResult` |
| `RetentionEngine` | `@MainActor public final class` | `public final class` (no longer MainActor) |

All callers must add `await` at call sites. The `record()` method remains synchronous.
