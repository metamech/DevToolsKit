import Foundation
import SQLite3

/// Low-level SQLite file-stat and compaction helpers.
///
/// ## Runtime vs. at-launch compaction (Option D)
///
/// At runtime the metrics store holds a live `ModelContainer` connection.
/// `wal_checkpoint(TRUNCATE)` requires zero active WAL readers to fully
/// truncate; SwiftData's connection can hold a snapshot that blocks it.
/// Therefore at runtime we use only `wal_checkpoint(RESTART)` — which folds
/// WAL frames into the main file and resets the WAL write position without
/// requiring full truncation — to bound WAL growth after pruning.
///
/// Actual file shrinkage (VACUUM) is deferred to app launch via
/// ``launchVacuum(dbURL:)``, called from `MetricsStack.create` before the
/// `ModelContainer` is constructed, when no readers can be present.
///
/// See `docs/ADR/ADR-001-metrics-size-cap-deferred-vacuum.md`.
enum MetricsDatabaseFileStats {

    // MARK: - File Size

    /// Sum of `.db` + `-wal` + `-shm` file sizes.
    ///
    /// SQLite names WAL sidecars by appending `-wal` / `-shm` as a literal
    /// suffix to the database filename (e.g. `metrics.store-wal`), not as a
    /// file extension. Missing sidecars count as 0.
    static func totalOnDiskBytes(dbURL: URL) -> Int64 {
        let fm = FileManager.default
        func fileSize(_ path: String) -> Int64 {
            (try? fm.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
        }
        let base = dbURL.path
        return fileSize(base) + fileSize(base + "-wal") + fileSize(base + "-shm")
    }

    // MARK: - Runtime Checkpoint (RESTART)

    /// Opens a raw `sqlite3` handle alongside the live SwiftData connection
    /// and runs `wal_checkpoint(RESTART)` to fold WAL frames into the main
    /// database file and reset the WAL write position.
    ///
    /// **RESTART vs TRUNCATE**: RESTART does not require zero active WAL
    /// readers, so it succeeds even while SwiftData's `ModelContainer` holds
    /// its connection open. It bounds WAL growth without requiring the file
    /// to physically shrink — physical shrinkage is handled at launch by
    /// ``launchVacuum(dbURL:)``.
    ///
    /// `sqlite3_busy_timeout(5000)` is set so the checkpoint waits up to 5 s
    /// for any brief lock contention rather than returning `SQLITE_BUSY`
    /// immediately.
    ///
    /// - Throws: ``MetricsDatabaseError/sqliteOpenFailed`` if the handle
    ///   cannot be opened; ``MetricsDatabaseError/checkpointFailed`` if
    ///   `sqlite3_wal_checkpoint_v2` returns non-OK.
    static func checkpointRestart(dbURL: URL) throws {
        let path = dbURL.path
        var db: OpaquePointer?
        let openRC = sqlite3_open_v2(
            path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX, nil
        )
        guard openRC == SQLITE_OK, let db else {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) }
                ?? "open returned \(openRC)"
            sqlite3_close(db)
            throw MetricsDatabaseError.sqliteOpenFailed(path: path, message: msg)
        }
        defer { sqlite3_close(db) }

        sqlite3_busy_timeout(db, 5_000)

        var nLog: Int32 = 0
        var nCkpt: Int32 = 0
        let rc = sqlite3_wal_checkpoint_v2(
            db, nil, SQLITE_CHECKPOINT_RESTART, &nLog, &nCkpt
        )
        if rc != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(db))
            throw MetricsDatabaseError.checkpointFailed(message: msg)
        }
        // Partial frame counts (nLog != nCkpt) are normal for RESTART when
        // readers hold a snapshot; we do not throw on them.
    }

    // MARK: - At-Launch Compaction (TRUNCATE + VACUUM)

    /// Called from `MetricsStack.create` **before** `ModelContainer` is
    /// constructed, when no reader connections exist on the file.
    ///
    /// Runs `wal_checkpoint(TRUNCATE)` to fold and zero the WAL, then
    /// `VACUUM` to rebuild the main database file and reclaim freed pages
    /// left by previous runtime pruning passes.
    ///
    /// - Parameters:
    ///   - dbURL: Path to the SQLite store file.
    ///   - warnThresholdSeconds: Log a warning to stderr if the operation
    ///     exceeds this duration. Defaults to 0.5 s.
    /// - Throws: ``MetricsDatabaseError`` on open or checkpoint failure.
    ///   VACUUM failures are logged but not thrown — startup must not be
    ///   blocked by a non-critical compaction step.
    static func launchVacuum(dbURL: URL, warnThresholdSeconds: Double = 0.5) throws {
        let path = dbURL.path
        let start = Date()

        var db: OpaquePointer?
        let openRC = sqlite3_open_v2(
            path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX, nil
        )
        guard openRC == SQLITE_OK, let db else {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) }
                ?? "open returned \(openRC)"
            sqlite3_close(db)
            throw MetricsDatabaseError.sqliteOpenFailed(path: path, message: msg)
        }
        defer {
            sqlite3_close(db)
            let elapsed = Date().timeIntervalSince(start)
            if elapsed > warnThresholdSeconds {
                fputs(
                    "[MetricsStore] launchVacuum took \(String(format: "%.3f", elapsed))s"
                        + " (threshold \(warnThresholdSeconds)s) at '\(path)'\n",
                    stderr
                )
            }
        }

        // No busy timeout needed: no other connection exists at launch time,
        // so wal_checkpoint(TRUNCATE) can fully fold and zero the WAL.
        var nLog: Int32 = 0
        var nCkpt: Int32 = 0
        let ckRC = sqlite3_wal_checkpoint_v2(
            db, nil, SQLITE_CHECKPOINT_TRUNCATE, &nLog, &nCkpt
        )
        if ckRC != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(db))
            throw MetricsDatabaseError.checkpointFailed(message: msg)
        }

        var errMsg: UnsafeMutablePointer<CChar>?
        let vacRC = sqlite3_exec(db, "VACUUM;", nil, nil, &errMsg)
        if vacRC != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "rc=\(vacRC)"
            sqlite3_free(errMsg)
            // Non-fatal: the WAL is already truncated; startup continues.
            fputs("[MetricsStore] launchVacuum VACUUM warning at '\(path)': \(msg)\n", stderr)
        }
    }
}

// MARK: - Errors

/// Errors surfaced by ``MetricsDatabaseFileStats``.
enum MetricsDatabaseError: Error, CustomStringConvertible {
    /// `sqlite3_open_v2` returned a non-OK result code.
    case sqliteOpenFailed(path: String, message: String)
    /// `sqlite3_wal_checkpoint_v2` returned a non-OK result code.
    case checkpointFailed(message: String)

    var description: String {
        switch self {
        case .sqliteOpenFailed(let path, let message):
            return "sqlite3_open_v2 failed at '\(path)': \(message)"
        case .checkpointFailed(let message):
            return "wal_checkpoint failed: \(message)"
        }
    }
}
