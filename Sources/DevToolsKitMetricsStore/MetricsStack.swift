import DevToolsKitMetrics
import Foundation
import SwiftData

/// Convenience factory for bootstrapping the full metrics persistence stack.
///
/// Creates and wires together a ``PersistentMetricsStorage``, ``MetricsDatabase``,
/// and ``RetentionEngine`` backed by a single `ModelContainer`.
///
/// ```swift
/// let stack = try MetricsStack.create(inMemory: true)
/// let result = await stack.database.execute(DatabaseQuery(
///     labelFilter: .prefix("http."),
///     timeBucket: .hour,
///     aggregation: .avg
/// ))
/// ```
///
/// ## Size ceiling and deferred VACUUM
///
/// When `retentionPolicy.sizeCeilingBytes` is non-nil, `create` runs
/// `wal_checkpoint(TRUNCATE)` + `VACUUM` against the store file **before**
/// constructing the `ModelContainer`.  At this point no reader connections
/// exist, so the checkpoint can fully truncate the WAL and VACUUM can
/// physically shrink the `.db` file to reclaim space freed by previous
/// runtime pruning passes.
///
/// Runtime pruning (``RetentionEngine``) uses only
/// `wal_checkpoint(RESTART)` — which does not require zero readers — to
/// bound WAL growth between launches.
///
/// See `docs/ADR/ADR-001-metrics-size-cap-deferred-vacuum.md`.
///
/// > Since: 0.3.0
@MainActor
public struct MetricsStack: Sendable {
    /// The persistent storage backend.
    public let storage: PersistentMetricsStorage
    /// The query facade.
    public let database: MetricsDatabase
    /// The retention engine for rollups and purging.
    public let retentionEngine: RetentionEngine
    /// The underlying SwiftData model container.
    public let modelContainer: ModelContainer

    /// All SwiftData model types used by this stack.
    public static var modelTypes: [any PersistentModel.Type] {
        MetricsModelTypes.all
    }

    /// Create a complete metrics stack.
    ///
    /// When `retentionPolicy.sizeCeilingBytes` is non-nil and the store file
    /// already exists, a `wal_checkpoint(TRUNCATE)` + `VACUUM` is run before
    /// `ModelContainer` construction to reclaim space from previous runtime
    /// pruning.  Failures are logged to stderr but do not block startup.
    ///
    /// - Parameters:
    ///   - inMemory: If `true`, uses in-memory SwiftData storage (for testing).
    ///   - storeURL: Explicit on-disk path for the SQLite store. When `nil` and
    ///     `inMemory` is `false`, SwiftData uses its default app-support path.
    ///     Pass a custom URL in tests or when you need a specific file location.
    ///     Ignored when `inMemory` is `true`.
    ///   - retentionPolicy: The retention policy for automatic rollups and purging.
    ///   - batchSize: Number of entries to buffer before flushing.
    /// - Returns: A fully configured ``MetricsStack``.
    public static func create(
        inMemory: Bool = false,
        storeURL: URL? = nil,
        retentionPolicy: RetentionPolicy = .default,
        batchSize: Int = 50
    ) throws -> MetricsStack {
        let schema = Schema(modelTypes)
        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if let storeURL {
            config = ModelConfiguration(schema: schema, url: storeURL)
        } else {
            config = ModelConfiguration(schema: schema)
        }

        // At-launch VACUUM: runs before ModelContainer is constructed so no
        // reader connections exist.  Only attempted when:
        //   1. sizeCeilingBytes is non-nil (opt-in feature).
        //   2. Store is on-disk (not in-memory).
        //   3. Store file already exists (not first launch).
        if !inMemory, retentionPolicy.sizeCeilingBytes != nil {
            let dbURL = config.url
            if FileManager.default.fileExists(atPath: dbURL.path) {
                do {
                    try MetricsDatabaseFileStats.launchVacuum(dbURL: dbURL)
                } catch {
                    // Non-fatal: log and continue.  A failed launch VACUUM means
                    // the file is not yet compacted this session; the next launch
                    // will retry.
                    fputs(
                        "[MetricsStore] launchVacuum failed (non-fatal): \(error)\n",
                        stderr
                    )
                }
            }
        }

        let container = try ModelContainer(for: schema, configurations: [config])
        let storage = PersistentMetricsStorage(modelContainer: container, batchSize: batchSize)
        let database = MetricsDatabase(storage: storage, modelContainer: container)
        let engine = RetentionEngine(modelContainer: container, policy: retentionPolicy)

        return MetricsStack(
            storage: storage,
            database: database,
            retentionEngine: engine,
            modelContainer: container
        )
    }
}
