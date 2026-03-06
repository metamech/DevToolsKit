import Foundation
import SwiftData
import Testing

@testable import DevToolsKitMetrics
@testable import DevToolsKitMetricsStore

@Suite(.serialized)
@MainActor
struct GapFillTests {
    private func makeStack() throws -> MetricsStack {
        try MetricsStack.create(inMemory: true, batchSize: 1000)
    }

    @Test
    func zeroFill() throws {
        let stack = try makeStack()
        let base = Date(timeIntervalSinceReferenceDate: 0)

        // Record at hours 0, 2, 4 (gaps at 1 and 3)
        for h in [0, 2, 4] {
            stack.storage.record(MetricEntry(
                timestamp: base.addingTimeInterval(Double(h) * 3600),
                label: "gap",
                dimensions: [],
                type: .counter,
                value: Double(h + 1)
            ))
        }
        stack.storage.flushNow()

        let result = stack.database.execute(DatabaseQuery(
            labelFilter: .exact("gap"),
            startDate: base,
            endDate: base.addingTimeInterval(4 * 3600),
            timeBucket: .hour,
            aggregation: .sum,
            gapFill: .zero,
            preferRollups: false,
            sortBy: .timeAscending
        ))

        #expect(result.rows.count == 5)
        // Hours 1 and 3 should be zero-filled
        #expect(result.rows[1].value == 0)
        #expect(result.rows[1].count == 0)
        #expect(result.rows[3].value == 0)
        #expect(result.rows[3].count == 0)
    }

    @Test
    func carryForward() throws {
        let stack = try makeStack()
        let base = Date(timeIntervalSinceReferenceDate: 0)

        // Record at hours 0 and 3
        stack.storage.record(MetricEntry(
            timestamp: base,
            label: "carry",
            dimensions: [],
            type: .counter,
            value: 10
        ))
        stack.storage.record(MetricEntry(
            timestamp: base.addingTimeInterval(3 * 3600),
            label: "carry",
            dimensions: [],
            type: .counter,
            value: 20
        ))
        stack.storage.flushNow()

        let result = stack.database.execute(DatabaseQuery(
            labelFilter: .exact("carry"),
            startDate: base,
            endDate: base.addingTimeInterval(3 * 3600),
            timeBucket: .hour,
            aggregation: .sum,
            gapFill: .carryForward,
            preferRollups: false,
            sortBy: .timeAscending
        ))

        #expect(result.rows.count == 4)
        #expect(result.rows[0].value == 10)
        #expect(result.rows[1].value == 10) // carried from hour 0
        #expect(result.rows[2].value == 10) // carried from hour 0
        #expect(result.rows[3].value == 20)
    }

    @Test
    func noFill() throws {
        let stack = try makeStack()
        let base = Date(timeIntervalSinceReferenceDate: 0)

        stack.storage.record(MetricEntry(
            timestamp: base,
            label: "nofill",
            dimensions: [],
            type: .counter,
            value: 1
        ))
        stack.storage.record(MetricEntry(
            timestamp: base.addingTimeInterval(3 * 3600),
            label: "nofill",
            dimensions: [],
            type: .counter,
            value: 2
        ))
        stack.storage.flushNow()

        let result = stack.database.execute(DatabaseQuery(
            labelFilter: .exact("nofill"),
            timeBucket: .hour,
            aggregation: .sum,
            gapFill: .none,
            preferRollups: false,
            sortBy: .timeAscending
        ))

        // Should only have 2 rows (no gap filling)
        #expect(result.rows.count == 2)
    }
}
