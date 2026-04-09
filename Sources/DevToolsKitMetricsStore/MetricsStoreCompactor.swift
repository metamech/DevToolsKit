import Foundation

/// Public entry point for at-launch metrics store compaction.
///
/// Callers that manage their own `ModelContainer` lifecycle (e.g. those that
/// wrap container creation with custom recovery logic) can call
/// ``launchVacuum(storeURL:)`` *before* opening the container to get the same
/// TRUNCATE-checkpoint + VACUUM that ``MetricsStack/create(inMemory:storeURL:retentionPolicy:batchSize:)``
/// performs internally.
///
/// ## When to use
///
/// Use this when you cannot switch to `MetricsStack.create` — for example,
/// because you need crash-recovery around `ModelContainer` construction.
/// Call it only when `sizeCeilingBytes` is non-nil on your `RetentionPolicy`
/// (size-based pruning must be enabled for compaction to be meaningful).
///
/// ```swift
/// let metricsStoreURL = supportDir.appendingPathComponent("metrics.store")
/// if FileManager.default.fileExists(atPath: metricsStoreURL.path) {
///     try? MetricsStoreCompactor.launchVacuum(storeURL: metricsStoreURL)
/// }
/// // Now safe to open the ModelContainer.
/// ```
///
/// ## Safety
///
/// This function opens its own `sqlite3` handle and closes it before
/// returning.  Call it only before any `ModelContainer` backed by the same
/// file is constructed; calling it while a container is open will likely fail
/// the TRUNCATE checkpoint (blocked by SwiftData's reader connection).
///
/// > Since: 0.10.1
public enum MetricsStoreCompactor {

    /// Run `wal_checkpoint(TRUNCATE)` + `VACUUM` on the metrics store file.
    ///
    /// - Parameters:
    ///   - storeURL: Path to the SQLite metrics store (`.db` file).
    ///   - warnThresholdSeconds: Write a warning to stderr if the operation
    ///     exceeds this duration. Defaults to 0.5 s.
    /// - Throws: An error if the SQLite file cannot be opened or if the
    ///   WAL checkpoint fails.  VACUUM failures are logged to stderr but
    ///   do not throw — startup must not be blocked by a non-critical
    ///   compaction step.
    public static func launchVacuum(
        storeURL: URL,
        warnThresholdSeconds: Double = 0.5
    ) throws {
        try MetricsDatabaseFileStats.launchVacuum(
            dbURL: storeURL,
            warnThresholdSeconds: warnThresholdSeconds
        )
    }
}
