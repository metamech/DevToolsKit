import DevToolsKitMetrics
import Foundation
import SwiftData

/// Manages automatic rollup creation and data retention for the metrics store.
///
/// The engine runs periodic maintenance cycles that:
/// 1. Create hourly rollups from completed-hour raw observations
/// 2. Create daily rollups from completed-day hourly rollups
/// 3. Purge raw observations older than ``RetentionPolicy/rawDataTTL``
/// 4. Purge hourly rollups older than ``RetentionPolicy/hourlyRollupTTL``
/// 5. Purge daily rollups older than ``RetentionPolicy/dailyRollupTTL``
/// 6. Update metric definitions
///
/// All maintenance work is delegated to the shared ``MetricsStoreActor``,
/// which owns the sole production `ModelContext`. This eliminates the
/// concurrent-context data races that caused `EXC_BREAKPOINT` crashes (#1460).
///
/// > Since: 0.3.0
/// > Breaking change in 0.7.0: `runMaintenanceCycle()` is now `async`.
/// > Breaking change in 0.11.0: `init(modelContainer:policy:)` removed;
/// > `MaintenanceWorker` removed; use `init(metricsActor:policy:)`.
public final class RetentionEngine: Sendable {
    private let metricsActor: MetricsStoreActor
    private let policy: RetentionPolicy
    private let lock = NSLock()
    private nonisolated(unsafe) var _maintenanceTask: Task<Void, Never>?

    /// Creates a retention engine that delegates all maintenance to the shared actor.
    ///
    /// - Parameters:
    ///   - metricsActor: The shared actor that owns the sole `ModelContext`. Must be
    ///     the same actor used by ``MetricsDatabase`` and ``PersistentMetricsStorage``.
    ///   - policy: The retention policy governing TTLs and size ceiling.
    public init(metricsActor: MetricsStoreActor, policy: RetentionPolicy = .default) {
        self.metricsActor = metricsActor
        self.policy = policy
    }

    deinit {
        _maintenanceTask?.cancel()
    }

    /// Start the periodic maintenance cycle.
    ///
    /// Launches a detached utility-priority task that runs maintenance at
    /// the interval specified by the retention policy.
    public func start() {
        lock.lock()
        defer { lock.unlock() }
        guard _maintenanceTask == nil else { return }
        let interval = policy.maintenanceInterval
        let actor = metricsActor
        let policy = self.policy
        _maintenanceTask = Task.detached(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                let dbURL = await actor.dbURL
                try? await actor.runMaintenanceCycle(policy: policy, dbURL: dbURL)
                try? await Task.sleep(for: .seconds(interval))
                if self == nil { break }
            }
        }
    }

    /// Stop the periodic maintenance cycle.
    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        _maintenanceTask?.cancel()
        _maintenanceTask = nil
    }

    /// Run a single maintenance cycle.
    ///
    /// > Since: 0.7.0 — now `async`. Previously synchronous and `@MainActor`-isolated.
    public func runMaintenanceCycle() async throws {
        let dbURL = await metricsActor.dbURL
        try await metricsActor.runMaintenanceCycle(policy: policy, dbURL: dbURL)
    }

    /// Enforce the size ceiling defined in the retention policy.
    ///
    /// Prunes oldest raw observations until total on-disk size falls below
    /// `sizeCeilingBytes * sizeCeilingFloorRatio`. Returns `true` if pruning
    /// occurred, `false` if the ceiling is disabled or was not exceeded.
    @discardableResult
    public func enforceSizeCeiling() async throws -> Bool {
        let dbURL = await metricsActor.dbURL
        return try await metricsActor.enforceSizeCeiling(policy: policy, dbURL: dbURL)
    }
}
