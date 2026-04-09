# ADR-001: Metrics Store Size Cap — Deferred VACUUM (Option D)

**Status**: Accepted
**Date**: 2026-04-09
**Issue**: metamech/Tenrec-Terminal#1380

## Context

`DevToolsKitMetricsStore` needed a hard ceiling on total on-disk size
(`.db` + `-wal` + `-shm`) with hysteresis-based pruning of the oldest raw
observations when the ceiling is exceeded.

The natural implementation — delete rows at runtime, then
`wal_checkpoint(TRUNCATE)` + `VACUUM` to physically reclaim space — does
not work reliably while a `ModelContainer` is live.

### The SwiftData reader-snapshot problem

`wal_checkpoint(TRUNCATE)` requires **zero active WAL readers** to fully
truncate the WAL file. SwiftData's `ModelContainer` holds an open sqlite3
connection that can hold a reader snapshot between operations. When our raw
sqlite3 handle issues `PRAGMA wal_checkpoint(TRUNCATE)`, SQLite returns
`SQLITE_BUSY` or a partial checkpoint if that snapshot is alive.
`VACUUM` then runs against a file that still contains WAL overhead, so the
on-disk footprint does not shrink — or even grows, because delete journalling
added WAL frames during the pruning loop.

Using `sqlite3_busy_timeout` reduces the window but cannot eliminate it:
SwiftData may re-enter a read transaction at any point on the main thread.

## Decision: Option D — runtime RESTART, launch VACUUM

**Runtime path** (`RetentionEngine.enforceSizeCeiling`):

1. Delete oldest `MetricObservation` rows in 500-row batches via a locally
   scoped `ModelContext` (released before step 2).
2. Run `wal_checkpoint(RESTART)` via a raw sqlite3 handle with
   `sqlite3_busy_timeout(5000)`. RESTART folds WAL frames into the main file
   and resets the write position without requiring zero readers. This bounds
   WAL growth between launches.
3. Do **not** call VACUUM at runtime.

**At-launch path** (`MetricsStack.create`, before `ModelContainer` init):

When `retentionPolicy.sizeCeilingBytes != nil` and the store file exists,
run `wal_checkpoint(TRUNCATE)` + `VACUUM` against the file before any
connection is opened. No readers exist at this point, so truncation
succeeds unconditionally and VACUUM physically compacts the `.db` file.
Failures are logged to stderr and do not block app startup.

## Consequences

- File does not shrink to floor within the same run that triggers pruning.
  It shrinks on the **next launch** after pruning occurred.
- Tests that assert `afterSize < beforeSize` within a single run must use
  `MetricsStack.create` (which triggers the launch VACUUM) rather than
  calling `enforceSizeCeiling` alone.
- WAL is bounded at runtime: delete deltas are committed and folded by
  RESTART, so WAL does not grow unboundedly between launches.

## Known future work

`MetricsStack.quiesceForMaintenance()` — an in-process quiesce API that
pauses all SwiftData contexts, enabling runtime `wal_checkpoint(TRUNCATE)` +
VACUUM without deferring to launch. Tracked as a follow-up to #1380.
