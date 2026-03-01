import Foundation

/// Audit entry recording a permission decision.
///
/// Since 0.4.0
public struct PermissionAuditEntry: Sendable, Codable, Identifiable {
    /// Unique identifier.
    public let id: UUID

    /// Timestamp of the decision.
    public let timestamp: Date

    /// Name of the operation.
    public let operationName: String

    /// Category of the operation.
    public let category: OperationCategory

    /// Configured permission level that was applied.
    public let configuredLevel: PermissionLevel

    /// Source of the permission configuration.
    public let source: PermissionSource

    /// User's decision.
    public let decision: PermissionResponse

    /// Summary of arguments (for debugging).
    public let argumentsSummary: String

    /// Creates a permission audit entry.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - timestamp: Timestamp of the decision (defaults to now).
    ///   - operationName: Name of the operation.
    ///   - category: Category of the operation.
    ///   - configuredLevel: Configured permission level that was applied.
    ///   - source: Source of the permission configuration.
    ///   - decision: User's decision.
    ///   - argumentsSummary: Summary of arguments.
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        operationName: String,
        category: OperationCategory,
        configuredLevel: PermissionLevel,
        source: PermissionSource,
        decision: PermissionResponse,
        argumentsSummary: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.operationName = operationName
        self.category = category
        self.configuredLevel = configuredLevel
        self.source = source
        self.decision = decision
        self.argumentsSummary = argumentsSummary
    }
}
