import DevToolsKitMetrics
import Foundation

/// An enhanced query for the persistent metrics database.
///
/// Supports label filtering, dimension filtering, time ranges, time bucketing,
/// aggregation functions, dimension grouping, gap filling, rollup preference,
/// sorting, and limiting.
///
/// > Since: 0.3.0
public struct DatabaseQuery: Sendable {
    /// Filter by metric label.
    public var labelFilter: LabelFilter?
    /// Filter by metric type.
    public var typeFilter: MetricType?
    /// Filter by required dimension key-value pairs.
    public var dimensionFilters: [(String, String)]?
    /// Include only observations at or after this date.
    public var startDate: Date?
    /// Include only observations at or before this date.
    public var endDate: Date?
    /// Bucket observations by time interval.
    public var timeBucket: TimeBucket?
    /// Aggregation function to apply.
    public var aggregation: AggregationFunction?
    /// Group results by this dimension key.
    public var groupByDimension: String?
    /// Strategy for filling gaps in time-bucketed results.
    public var gapFill: GapFillStrategy
    /// Prefer pre-computed rollups when available.
    public var preferRollups: Bool
    /// Maximum number of result rows.
    public var limit: Int?
    /// Sort order for results.
    public var sortBy: ResultSort

    public init(
        labelFilter: LabelFilter? = nil,
        typeFilter: MetricType? = nil,
        dimensionFilters: [(String, String)]? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        timeBucket: TimeBucket? = nil,
        aggregation: AggregationFunction? = nil,
        groupByDimension: String? = nil,
        gapFill: GapFillStrategy = .none,
        preferRollups: Bool = true,
        limit: Int? = nil,
        sortBy: ResultSort = .timeDescending
    ) {
        self.labelFilter = labelFilter
        self.typeFilter = typeFilter
        self.dimensionFilters = dimensionFilters
        self.startDate = startDate
        self.endDate = endDate
        self.timeBucket = timeBucket
        self.aggregation = aggregation
        self.groupByDimension = groupByDimension
        self.gapFill = gapFill
        self.preferRollups = preferRollups
        self.limit = limit
        self.sortBy = sortBy
    }
}
