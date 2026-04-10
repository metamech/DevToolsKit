import Foundation

/// A hook called before ``RetentionEngine`` permanently deletes ``MetricObservation`` rows.
///
/// Implement this protocol to export or persist observations that are about to be pruned.
/// Errors thrown by the archiver are logged at warning level and swallowed — they never
/// block or abort the deletion that follows.
///
/// Implementations receive ``ArchivedObservation`` value types rather than live `@Model`
/// objects. Data is extracted synchronously on the actor before any `await`, so conforming
/// types never need to touch `@Model` instances or a `ModelContext`.
///
/// > Since: 0.9.0 (updated to value types in 0.12.0)
public protocol RetentionArchiver: Sendable {
    /// Called with a batch of observations that are about to be deleted.
    ///
    /// - Parameters:
    ///   - observations: Sendable snapshots of the observations scheduled for deletion.
    ///   - reason: Why the batch is being pruned (TTL expiry or size-cap enforcement).
    func archive(observations: [ArchivedObservation], reason: RetentionPruneReason) async throws
}

/// The reason a batch of ``MetricObservation`` rows is being pruned.
///
/// > Since: 0.9.0
public enum RetentionPruneReason: Sendable {
    /// The observations exceeded the TTL defined by ``RetentionPolicy/rawDataTTL``.
    case ttl
    /// The observations are being removed to bring the store below ``RetentionPolicy/sizeCeilingBytes``.
    case sizeCap
}
