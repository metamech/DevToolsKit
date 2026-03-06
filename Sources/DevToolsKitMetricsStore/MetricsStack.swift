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
/// let result = stack.database.execute(DatabaseQuery(
///     labelFilter: .prefix("http."),
///     timeBucket: .hour,
///     aggregation: .avg
/// ))
/// ```
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
    /// - Parameters:
    ///   - inMemory: If `true`, uses in-memory SwiftData storage (for testing).
    ///   - retentionPolicy: The retention policy for automatic rollups and purging.
    ///   - batchSize: Number of entries to buffer before flushing.
    /// - Returns: A fully configured ``MetricsStack``.
    public static func create(
        inMemory: Bool = false,
        retentionPolicy: RetentionPolicy = .default,
        batchSize: Int = 50
    ) throws -> MetricsStack {
        let schema = Schema(modelTypes)
        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            config = ModelConfiguration(schema: schema)
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
