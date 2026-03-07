import Foundation
import SwiftData
import Testing

@testable import DevToolsKitMetrics
@testable import DevToolsKitMetricsStore

@Suite(.serialized)
@MainActor
struct DatabaseQueryTests {
    private func makeStack() throws -> MetricsStack {
        try MetricsStack.create(inMemory: true, batchSize: 1000)
    }

    private func recordEntries(
        _ storage: PersistentMetricsStorage,
        label: String = "test",
        count: Int = 10,
        baseTime: Date = Date(),
        interval: TimeInterval = 60,
        dimensions: [(String, String)] = [],
        type: MetricType = .counter,
        valueGenerator: (Int) -> Double = { Double($0) }
    ) {
        for i in 0..<count {
            storage.record(
                MetricEntry(
                    timestamp: baseTime.addingTimeInterval(Double(i) * interval),
                    label: label,
                    dimensions: dimensions,
                    type: type,
                    value: valueGenerator(i)
                ))
        }
        storage.flushNow()
    }

    // MARK: - Label Filters

    @Test
    func exactLabelFilter() throws {
        let stack = try makeStack()
        recordEntries(stack.storage, label: "http.requests", count: 3)
        recordEntries(stack.storage, label: "http.errors", count: 2)

        let result = stack.database.execute(
            DatabaseQuery(
                labelFilter: .exact("http.requests")
            ))
        #expect(result.rows.count == 3)
        #expect(result.rows.allSatisfy { $0.label == "http.requests" })
    }

    @Test
    func prefixLabelFilter() throws {
        let stack = try makeStack()
        recordEntries(stack.storage, label: "http.requests", count: 2)
        recordEntries(stack.storage, label: "http.errors", count: 2)
        recordEntries(stack.storage, label: "db.queries", count: 2)

        let result = stack.database.execute(
            DatabaseQuery(
                labelFilter: .prefix("http.")
            ))
        #expect(result.rows.count == 4)
    }

    @Test
    func containsLabelFilter() throws {
        let stack = try makeStack()
        recordEntries(stack.storage, label: "api.http.requests", count: 2)
        recordEntries(stack.storage, label: "web.http.errors", count: 2)
        recordEntries(stack.storage, label: "db.queries", count: 2)

        let result = stack.database.execute(
            DatabaseQuery(
                labelFilter: .contains("http")
            ))
        #expect(result.rows.count == 4)
    }

    // MARK: - Type Filter

    @Test
    func typeFilter() throws {
        let stack = try makeStack()
        recordEntries(stack.storage, label: "m", count: 3, type: .counter)
        recordEntries(stack.storage, label: "m", count: 2, type: .timer)

        let result = stack.database.execute(
            DatabaseQuery(
                typeFilter: .counter
            ))
        #expect(result.rows.count == 3)
    }

    // MARK: - Time Range

    @Test
    func timeRange() throws {
        let stack = try makeStack()
        let base = Date()
        recordEntries(stack.storage, count: 10, baseTime: base, interval: 60)

        let result = stack.database.execute(
            DatabaseQuery(
                startDate: base.addingTimeInterval(120),
                endDate: base.addingTimeInterval(420)
            ))
        // Entries at t=2,3,4,5,6,7 minutes (indices 2-7)
        #expect(result.rows.count == 6)
    }

    // MARK: - Dimension Filters

    @Test
    func dimensionFilters() throws {
        let stack = try makeStack()
        recordEntries(stack.storage, label: "d", count: 3, dimensions: [("env", "prod")])
        recordEntries(stack.storage, label: "d", count: 2, dimensions: [("env", "dev")])

        let result = stack.database.execute(
            DatabaseQuery(
                labelFilter: .exact("d"),
                dimensionFilters: [("env", "prod")]
            ))
        #expect(result.rows.count == 3)
    }

    // MARK: - Aggregation Functions

    @Test
    func sumAggregation() throws {
        let stack = try makeStack()
        recordEntries(stack.storage, label: "a", count: 5, valueGenerator: { Double($0 + 1) })

        let result = stack.database.execute(
            DatabaseQuery(
                labelFilter: .exact("a"),
                aggregation: .sum
            ))
        #expect(result.rows.count == 1)
        #expect(result.rows[0].value == 15)  // 1+2+3+4+5
    }

    @Test
    func avgAggregation() throws {
        let stack = try makeStack()
        recordEntries(stack.storage, label: "a", count: 5, valueGenerator: { Double($0 + 1) })

        let result = stack.database.execute(
            DatabaseQuery(
                labelFilter: .exact("a"),
                aggregation: .avg
            ))
        #expect(result.rows.count == 1)
        #expect(result.rows[0].value == 3)  // (1+2+3+4+5)/5
    }

    @Test
    func minMaxAggregation() throws {
        let stack = try makeStack()
        recordEntries(stack.storage, label: "a", count: 5, valueGenerator: { Double($0 + 1) })

        let minResult = stack.database.execute(
            DatabaseQuery(
                labelFilter: .exact("a"),
                aggregation: .min
            ))
        #expect(minResult.rows[0].value == 1)

        let maxResult = stack.database.execute(
            DatabaseQuery(
                labelFilter: .exact("a"),
                aggregation: .max
            ))
        #expect(maxResult.rows[0].value == 5)
    }

    @Test
    func countAggregation() throws {
        let stack = try makeStack()
        recordEntries(stack.storage, label: "a", count: 7)

        let result = stack.database.execute(
            DatabaseQuery(
                labelFilter: .exact("a"),
                aggregation: .count
            ))
        #expect(result.rows[0].value == 7)
    }

    // MARK: - Time Bucketing

    @Test
    func timeBucketing() throws {
        let stack = try makeStack()
        let base = Date(timeIntervalSinceReferenceDate: 0)

        // 10 entries, 1 per minute → all within 10 minutes → 1 hourly bucket
        recordEntries(stack.storage, count: 10, baseTime: base, interval: 60)

        let result = stack.database.execute(
            DatabaseQuery(
                timeBucket: .hour,
                aggregation: .sum
            ))
        #expect(result.rows.count == 1)
        #expect(result.rows[0].value == 45)  // 0+1+...+9
    }

    @Test
    func timeBucketingMultipleBuckets() throws {
        let stack = try makeStack()
        let base = Date(timeIntervalSinceReferenceDate: 0)

        // 120 entries, 1 per minute → spans 2 hours
        recordEntries(stack.storage, count: 120, baseTime: base, interval: 60)

        let result = stack.database.execute(
            DatabaseQuery(
                timeBucket: .hour,
                aggregation: .count,
                sortBy: .timeAscending
            ))
        #expect(result.rows.count == 2)
        #expect(result.rows[0].value == 60)
        #expect(result.rows[1].value == 60)
    }

    // MARK: - Group By Dimension

    @Test
    func groupByDimension() throws {
        let stack = try makeStack()
        recordEntries(stack.storage, label: "g", count: 3, dimensions: [("env", "prod")], valueGenerator: { _ in 10 })
        recordEntries(stack.storage, label: "g", count: 2, dimensions: [("env", "dev")], valueGenerator: { _ in 5 })

        let result = stack.database.execute(
            DatabaseQuery(
                labelFilter: .exact("g"),
                aggregation: .sum,
                groupByDimension: "env"
            ))
        #expect(result.rows.count == 2)
        let prod = result.rows.first { $0.dimensionValue == "prod" }
        let dev = result.rows.first { $0.dimensionValue == "dev" }
        #expect(prod?.value == 30)
        #expect(dev?.value == 10)
    }

    // MARK: - Sorting

    @Test
    func sorting() throws {
        let stack = try makeStack()
        let base = Date(timeIntervalSinceReferenceDate: 0)
        recordEntries(stack.storage, count: 5, baseTime: base, interval: 60, valueGenerator: { Double($0) })

        let ascending = stack.database.execute(
            DatabaseQuery(
                sortBy: .valueAscending
            ))
        #expect(ascending.rows.first?.value == 0)
        #expect(ascending.rows.last?.value == 4)

        let descending = stack.database.execute(
            DatabaseQuery(
                sortBy: .valueDescending
            ))
        #expect(descending.rows.first?.value == 4)
        #expect(descending.rows.last?.value == 0)
    }

    // MARK: - Limiting

    @Test
    func limiting() throws {
        let stack = try makeStack()
        recordEntries(stack.storage, count: 20)

        let result = stack.database.execute(DatabaseQuery(limit: 5))
        #expect(result.rows.count == 5)
    }
}
