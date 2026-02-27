import Foundation

/// Sort order for metric query results.
public enum MetricsQuerySort: Sendable {
    case timestampAscending
    case timestampDescending
    case valueAscending
    case valueDescending
}

/// Describes filters and sorting for querying stored metric entries.
public struct MetricsQuery: Sendable {
    /// Filter by metric label (exact match).
    public var label: String?
    /// Filter by metric type.
    public var type: MetricType?
    /// Filter by required dimensions (all must be present).
    public var dimensions: [(String, String)]?
    /// Include only entries at or after this date.
    public var startDate: Date?
    /// Include only entries at or before this date.
    public var endDate: Date?
    /// Maximum number of results to return.
    public var limit: Int?
    /// Sort order for results.
    public var sort: MetricsQuerySort

    public init(
        label: String? = nil,
        type: MetricType? = nil,
        dimensions: [(String, String)]? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        limit: Int? = nil,
        sort: MetricsQuerySort = .timestampDescending
    ) {
        self.label = label
        self.type = type
        self.dimensions = dimensions
        self.startDate = startDate
        self.endDate = endDate
        self.limit = limit
        self.sort = sort
    }
}
