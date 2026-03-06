import Foundation

/// Configuration for automatic metric data retention and rollup.
///
/// > Since: 0.3.0
public struct RetentionPolicy: Sendable {
    /// How long to keep raw observations. Defaults to 7 days.
    public var rawDataTTL: TimeInterval
    /// How long to keep hourly rollups. Defaults to 90 days.
    public var hourlyRollupTTL: TimeInterval
    /// How long to keep daily rollups. Defaults to 365 days.
    public var dailyRollupTTL: TimeInterval
    /// Interval between maintenance cycles. Defaults to 15 minutes.
    public var maintenanceInterval: TimeInterval

    public init(
        rawDataTTL: TimeInterval = 7 * 86_400,
        hourlyRollupTTL: TimeInterval = 90 * 86_400,
        dailyRollupTTL: TimeInterval = 365 * 86_400,
        maintenanceInterval: TimeInterval = 15 * 60
    ) {
        self.rawDataTTL = rawDataTTL
        self.hourlyRollupTTL = hourlyRollupTTL
        self.dailyRollupTTL = dailyRollupTTL
        self.maintenanceInterval = maintenanceInterval
    }

    /// Default policy: 7d raw, 90d hourly, 365d daily, 15min maintenance.
    public static let `default` = RetentionPolicy()

    /// Compact policy: 1d raw, 30d hourly, 90d daily, 5min maintenance.
    public static let compact = RetentionPolicy(
        rawDataTTL: 1 * 86_400,
        hourlyRollupTTL: 30 * 86_400,
        dailyRollupTTL: 90 * 86_400,
        maintenanceInterval: 5 * 60
    )

    /// Development policy: 1h raw, 7d hourly, 30d daily, 1min maintenance.
    public static let development = RetentionPolicy(
        rawDataTTL: 3_600,
        hourlyRollupTTL: 7 * 86_400,
        dailyRollupTTL: 30 * 86_400,
        maintenanceInterval: 60
    )
}
