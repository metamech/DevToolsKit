import DevToolsKitMetrics
import Foundation
import SwiftData

/// Internal query execution engine.
///
/// Responsible for strategy selection (rollups vs raw), predicate construction,
/// and in-memory post-processing (dimension filtering, grouping, aggregation,
/// gap filling, sorting, limiting).
@MainActor
enum QueryExecutor {
    /// Execute a ``DatabaseQuery`` against the given model context.
    static func execute(
        _ query: DatabaseQuery,
        context: ModelContext,
        unflushedEntries: [MetricEntry] = []
    ) throws -> QueryResult {
        // Try rollups first if preferred and applicable
        if query.preferRollups, let timeBucket = query.timeBucket,
            let agg = query.aggregation,
            query.groupByDimension == nil,
            let labelFilter = query.labelFilter,
            case .exact(let label) = labelFilter
        {
            let rollupGranularity = rollupGranularity(for: timeBucket)
            if let granularity = rollupGranularity {
                let result = try executeFromRollups(
                    query, label: label, granularity: granularity,
                    aggregation: agg, timeBucket: timeBucket, context: context
                )
                if !result.rows.isEmpty {
                    return result
                }
            }
        }

        return try executeFromRaw(query, context: context, unflushedEntries: unflushedEntries)
    }

    // MARK: - Raw Observation Path

    private static func executeFromRaw(
        _ query: DatabaseQuery,
        context: ModelContext,
        unflushedEntries: [MetricEntry]
    ) throws -> QueryResult {
        var descriptor = FetchDescriptor<MetricObservation>()
        var predicates: [Predicate<MetricObservation>] = []

        // Label predicate (exact only at SwiftData level; prefix/contains filtered in-memory)
        if let labelFilter = query.labelFilter {
            switch labelFilter {
            case .exact(let value):
                let label = value
                predicates.append(#Predicate { $0.label == label })
            case .prefix, .contains:
                break  // filtered in-memory below
            }
        }

        // Type predicate
        if let typeFilter = query.typeFilter {
            let raw = typeFilter.rawValue
            predicates.append(#Predicate { $0.typeRawValue == raw })
        }

        // Time range predicates
        if let start = query.startDate {
            let startDate = start
            predicates.append(#Predicate { $0.timestamp >= startDate })
        }
        if let end = query.endDate {
            let endDate = end
            predicates.append(#Predicate { $0.timestamp <= endDate })
        }

        // Combine predicates
        if !predicates.isEmpty {
            descriptor.predicate = combinePredicates(predicates)
        }

        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]

        let observations = try context.fetch(descriptor)
        var entries = observations.map { $0.toMetricEntry() }

        // Merge unflushed entries
        let filtered = filterEntries(unflushedEntries, matching: query)
        entries.append(contentsOf: filtered)
        entries.sort { $0.timestamp < $1.timestamp }

        let totalScanned = entries.count

        // In-memory label filtering for prefix/contains
        if let labelFilter = query.labelFilter {
            entries = entries.filter { labelFilter.matches($0.label) }
        }

        // Dimension filtering
        if let dimFilters = query.dimensionFilters {
            entries = entries.filter { entry in
                dimFilters.allSatisfy { req in
                    entry.dimensions.contains { $0.0 == req.0 && $0.1 == req.1 }
                }
            }
        }

        // Group and aggregate
        let rows: [QueryResultRow]
        if let timeBucket = query.timeBucket {
            rows = bucketAndAggregate(
                entries, timeBucket: timeBucket,
                aggregation: query.aggregation ?? .avg,
                groupByDimension: query.groupByDimension,
                gapFill: query.gapFill,
                startDate: query.startDate,
                endDate: query.endDate
            )
        } else if let groupBy = query.groupByDimension {
            rows = groupByDimensionAndAggregate(
                entries, dimensionKey: groupBy,
                aggregation: query.aggregation ?? .avg
            )
        } else if let agg = query.aggregation {
            // Aggregate all entries into a single row per label
            rows = aggregateByLabel(entries, aggregation: agg)
        } else {
            // Raw entries as rows
            rows = entries.map { entry in
                QueryResultRow(
                    label: entry.label,
                    bucketStart: entry.timestamp,
                    value: entry.value,
                    count: 1
                )
            }
        }

        // Sort
        let sorted = sortRows(rows, by: query.sortBy)

        // Limit
        let limited = query.limit.map { Array(sorted.prefix($0)) } ?? sorted

        return QueryResult(rows: limited, observationsScanned: totalScanned)
    }

    // MARK: - Rollup Path

    private static func rollupGranularity(for bucket: TimeBucket) -> String? {
        switch bucket {
        case .hour: "hourly"
        case .day: "daily"
        default: nil
        }
    }

    private static func executeFromRollups(
        _ query: DatabaseQuery,
        label: String,
        granularity: String,
        aggregation: AggregationFunction,
        timeBucket: TimeBucket,
        context: ModelContext
    ) throws -> QueryResult {
        var descriptor = FetchDescriptor<MetricRollup>()
        var predicates: [Predicate<MetricRollup>] = []

        let lbl = label
        let gran = granularity
        predicates.append(#Predicate { $0.label == lbl && $0.granularity == gran })

        if let typeFilter = query.typeFilter {
            let raw = typeFilter.rawValue
            predicates.append(#Predicate { $0.typeRawValue == raw })
        }

        if let start = query.startDate {
            let startDate = start
            predicates.append(#Predicate { $0.bucketStart >= startDate })
        }
        if let end = query.endDate {
            let endDate = end
            predicates.append(#Predicate { $0.bucketEnd <= endDate })
        }

        if !predicates.isEmpty {
            descriptor.predicate = combineRollupPredicates(predicates)
        }

        descriptor.sortBy = [SortDescriptor(\.bucketStart, order: .forward)]

        let rollups = try context.fetch(descriptor)
        guard !rollups.isEmpty else {
            return QueryResult(rows: [])
        }

        var rows = rollups.map { rollup in
            let value: Double =
                switch aggregation {
                case .sum: rollup.sum
                case .avg: rollup.avg
                case .min: rollup.min
                case .max: rollup.max
                case .count: Double(rollup.count)
                case .latest: rollup.avg  // best approximation from rollup
                case .p50, .p95, .p99: .nan  // percentiles unavailable from rollups
                }
            return QueryResultRow(
                label: rollup.label,
                bucketStart: rollup.bucketStart,
                value: value,
                count: rollup.count
            )
        }

        // Gap fill
        if query.gapFill != .none {
            rows = applyGapFill(
                rows, strategy: query.gapFill, timeBucket: timeBucket,
                startDate: query.startDate, endDate: query.endDate, label: label
            )
        }

        let sorted = sortRows(rows, by: query.sortBy)
        let limited = query.limit.map { Array(sorted.prefix($0)) } ?? sorted

        return QueryResult(rows: limited, observationsScanned: 0)
    }

    // MARK: - Bucketing & Aggregation

    private static func bucketAndAggregate(
        _ entries: [MetricEntry],
        timeBucket: TimeBucket,
        aggregation: AggregationFunction,
        groupByDimension: String?,
        gapFill: GapFillStrategy,
        startDate: Date?,
        endDate: Date?
    ) -> [QueryResultRow] {
        if let dimKey = groupByDimension {
            // Group by time bucket AND dimension value
            var groups: [String: [Date: [(Double, Date)]]] = [:]
            for entry in entries {
                let bucket = timeBucket.bucketStart(for: entry.timestamp)
                let dimValue = entry.dimensions.first { $0.0 == dimKey }?.1 ?? "(none)"
                groups[dimValue, default: [:]][bucket, default: []].append((entry.value, entry.timestamp))
            }

            var rows: [QueryResultRow] = []
            for (dimValue, buckets) in groups {
                for (bucket, pairs) in buckets {
                    let values = pairs.map(\.0)
                    let timestamps = pairs.map(\.1)
                    if let agg = aggregation.compute(values, timestamps: timestamps) {
                        rows.append(
                            QueryResultRow(
                                label: entries.first?.label ?? "",
                                dimensionValue: dimValue,
                                bucketStart: bucket,
                                value: agg,
                                count: values.count
                            ))
                    }
                }
            }
            return rows
        }

        // Group by time bucket only
        var buckets: [String: [Date: [(Double, Date)]]] = [:]
        for entry in entries {
            let bucket = timeBucket.bucketStart(for: entry.timestamp)
            buckets[entry.label, default: [:]][bucket, default: []].append((entry.value, entry.timestamp))
        }

        var rows: [QueryResultRow] = []
        for (label, labelBuckets) in buckets {
            for (bucket, pairs) in labelBuckets {
                let values = pairs.map(\.0)
                let timestamps = pairs.map(\.1)
                if let agg = aggregation.compute(values, timestamps: timestamps) {
                    rows.append(
                        QueryResultRow(
                            label: label,
                            bucketStart: bucket,
                            value: agg,
                            count: values.count
                        ))
                }
            }

            // Gap fill per label
            if gapFill != .none {
                let labelRows = rows.filter { $0.label == label }
                let filled = applyGapFill(
                    labelRows, strategy: gapFill, timeBucket: timeBucket,
                    startDate: startDate, endDate: endDate, label: label
                )
                rows = rows.filter { $0.label != label } + filled
            }
        }

        return rows
    }

    private static func groupByDimensionAndAggregate(
        _ entries: [MetricEntry],
        dimensionKey: String,
        aggregation: AggregationFunction
    ) -> [QueryResultRow] {
        var groups: [String: [(Double, Date)]] = [:]
        for entry in entries {
            let dimValue = entry.dimensions.first { $0.0 == dimensionKey }?.1 ?? "(none)"
            groups[dimValue, default: []].append((entry.value, entry.timestamp))
        }

        return groups.compactMap { dimValue, pairs in
            let values = pairs.map(\.0)
            let timestamps = pairs.map(\.1)
            guard let agg = aggregation.compute(values, timestamps: timestamps) else { return nil }
            return QueryResultRow(
                label: entries.first?.label ?? "",
                dimensionValue: dimValue,
                value: agg,
                count: values.count
            )
        }
    }

    private static func aggregateByLabel(
        _ entries: [MetricEntry],
        aggregation: AggregationFunction
    ) -> [QueryResultRow] {
        var groups: [String: [(Double, Date)]] = [:]
        for entry in entries {
            groups[entry.label, default: []].append((entry.value, entry.timestamp))
        }

        return groups.compactMap { label, pairs in
            let values = pairs.map(\.0)
            let timestamps = pairs.map(\.1)
            guard let agg = aggregation.compute(values, timestamps: timestamps) else { return nil }
            return QueryResultRow(
                label: label,
                value: agg,
                count: values.count
            )
        }
    }

    // MARK: - Gap Filling

    private static func applyGapFill(
        _ rows: [QueryResultRow],
        strategy: GapFillStrategy,
        timeBucket: TimeBucket,
        startDate: Date?,
        endDate: Date?,
        label: String
    ) -> [QueryResultRow] {
        guard strategy != .none else { return rows }
        let sortedRows = rows.sorted { ($0.bucketStart ?? .distantPast) < ($1.bucketStart ?? .distantPast) }
        guard
            let firstBucket =
                (startDate.map { timeBucket.bucketStart(for: $0) }
                    ?? sortedRows.first?.bucketStart)
        else { return rows }
        let lastBucket =
            endDate.map { timeBucket.bucketStart(for: $0) }
            ?? sortedRows.last?.bucketStart ?? firstBucket

        var existing: [Date: QueryResultRow] = [:]
        for row in sortedRows {
            if let bs = row.bucketStart {
                existing[bs] = row
            }
        }

        var result: [QueryResultRow] = []
        var current = firstBucket
        var lastValue: Double = 0
        let interval = timeBucket.interval

        while current <= lastBucket {
            if let row = existing[current] {
                result.append(row)
                lastValue = row.value
            } else {
                let fillValue: Double =
                    switch strategy {
                    case .zero: 0
                    case .carryForward: lastValue
                    case .none: 0  // unreachable
                    }
                result.append(
                    QueryResultRow(
                        label: label,
                        bucketStart: current,
                        value: fillValue,
                        count: 0
                    ))
            }
            current = current.addingTimeInterval(interval)
        }

        return result
    }

    // MARK: - Sorting

    private static func sortRows(_ rows: [QueryResultRow], by sort: ResultSort) -> [QueryResultRow] {
        switch sort {
        case .valueAscending:
            rows.sorted { $0.value < $1.value }
        case .valueDescending:
            rows.sorted { $0.value > $1.value }
        case .labelAscending:
            rows.sorted { $0.label < $1.label }
        case .timeAscending:
            rows.sorted { ($0.bucketStart ?? .distantPast) < ($1.bucketStart ?? .distantPast) }
        case .timeDescending:
            rows.sorted { ($0.bucketStart ?? .distantFuture) > ($1.bucketStart ?? .distantFuture) }
        }
    }

    // MARK: - Helpers

    private static func filterEntries(
        _ entries: [MetricEntry],
        matching query: DatabaseQuery
    ) -> [MetricEntry] {
        var result = entries

        if let labelFilter = query.labelFilter {
            result = result.filter { labelFilter.matches($0.label) }
        }
        if let typeFilter = query.typeFilter {
            result = result.filter { $0.type == typeFilter }
        }
        if let start = query.startDate {
            result = result.filter { $0.timestamp >= start }
        }
        if let end = query.endDate {
            result = result.filter { $0.timestamp <= end }
        }
        if let dimFilters = query.dimensionFilters {
            result = result.filter { entry in
                dimFilters.allSatisfy { req in
                    entry.dimensions.contains { $0.0 == req.0 && $0.1 == req.1 }
                }
            }
        }

        return result
    }

    private static func combinePredicates(
        _ predicates: [Predicate<MetricObservation>]
    ) -> Predicate<MetricObservation> {
        guard var combined = predicates.first else {
            return #Predicate<MetricObservation> { _ in true }
        }
        for predicate in predicates.dropFirst() {
            let prev = combined
            let next = predicate
            combined = #Predicate { prev.evaluate($0) && next.evaluate($0) }
        }
        return combined
    }

    private static func combineRollupPredicates(
        _ predicates: [Predicate<MetricRollup>]
    ) -> Predicate<MetricRollup> {
        guard var combined = predicates.first else {
            return #Predicate<MetricRollup> { _ in true }
        }
        for predicate in predicates.dropFirst() {
            let prev = combined
            let next = predicate
            combined = #Predicate { prev.evaluate($0) && next.evaluate($0) }
        }
        return combined
    }
}
