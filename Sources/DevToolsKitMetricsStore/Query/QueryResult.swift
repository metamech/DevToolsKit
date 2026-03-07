import Foundation

/// The result of executing a ``DatabaseQuery``.
///
/// > Since: 0.3.0
public struct QueryResult: Sendable {
    /// The result rows.
    public let rows: [QueryResultRow]
    /// When this result was computed.
    public let computedAt: Date
    /// Number of raw observations scanned to produce this result.
    public let observationsScanned: Int

    public init(
        rows: [QueryResultRow],
        computedAt: Date = Date(),
        observationsScanned: Int = 0
    ) {
        self.rows = rows
        self.computedAt = computedAt
        self.observationsScanned = observationsScanned
    }
}

/// A single row in a ``QueryResult``.
///
/// > Since: 0.3.0
public struct QueryResultRow: Identifiable, Sendable {
    public let id: UUID
    /// The metric label.
    public let label: String
    /// Dimension value when grouped by a specific dimension key.
    public let dimensionValue: String?
    /// Start of the time bucket, if time-bucketed.
    public let bucketStart: Date?
    /// The aggregated value.
    public let value: Double
    /// Number of observations in this group.
    public let count: Int

    public init(
        id: UUID = UUID(),
        label: String,
        dimensionValue: String? = nil,
        bucketStart: Date? = nil,
        value: Double,
        count: Int
    ) {
        self.id = id
        self.label = label
        self.dimensionValue = dimensionValue
        self.bucketStart = bucketStart
        self.value = value
        self.count = count
    }
}
