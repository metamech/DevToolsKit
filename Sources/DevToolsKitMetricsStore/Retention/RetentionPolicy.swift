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

    /// Hard ceiling on total metrics store size on disk (sum of .db + -wal + -shm).
    /// When exceeded, the maintenance worker prunes oldest raw observations until
    /// total size ≤ sizeCeilingBytes * sizeCeilingFloorRatio (hysteresis).
    /// nil disables size-based pruning (default; only TTL pruning runs).
    public let sizeCeilingBytes: Int64?

    /// Low-water mark as a fraction of sizeCeilingBytes. Must be in (0.0, 1.0).
    /// Ignored when sizeCeilingBytes == nil.
    public let sizeCeilingFloorRatio: Double

    /// Optional hook called with each batch of ``MetricObservation`` rows immediately
    /// before they are permanently deleted.
    ///
    /// Archiver errors are logged at warning level and swallowed — a failing archiver
    /// never prevents deletion.  `nil` (the default) preserves the existing behavior
    /// and incurs no extra fetches.
    ///
    /// > Since: 0.9.0
    public var archiver: (any RetentionArchiver)?

    public init(
        rawDataTTL: TimeInterval = 7 * 86_400,
        hourlyRollupTTL: TimeInterval = 90 * 86_400,
        dailyRollupTTL: TimeInterval = 365 * 86_400,
        maintenanceInterval: TimeInterval = 15 * 60,
        sizeCeilingBytes: Int64? = nil,
        sizeCeilingFloorRatio: Double = 0.9,
        archiver: (any RetentionArchiver)? = nil
    ) {
        precondition(
            sizeCeilingFloorRatio > 0 && sizeCeilingFloorRatio < 1,
            "sizeCeilingFloorRatio must be in (0.0, 1.0)"
        )
        self.rawDataTTL = rawDataTTL
        self.hourlyRollupTTL = hourlyRollupTTL
        self.dailyRollupTTL = dailyRollupTTL
        self.maintenanceInterval = maintenanceInterval
        self.sizeCeilingBytes = sizeCeilingBytes
        self.sizeCeilingFloorRatio = sizeCeilingFloorRatio
        self.archiver = archiver
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
