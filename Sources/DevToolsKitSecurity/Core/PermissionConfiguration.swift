import Foundation

/// Configuration for operation permissions.
///
/// Permissions are resolved in order: per-operation override, then category default,
/// then hardcoded defaults.
///
/// Since 0.4.0
public struct PermissionConfiguration: Codable, Sendable, Hashable {
    /// Per-operation permission overrides (operation name -> permission level).
    public var perOperation: [String: PermissionLevel]

    /// Per-category default permissions.
    public var perCategory: [OperationCategory: PermissionLevel]

    /// Creates a permission configuration.
    /// - Parameters:
    ///   - perOperation: Per-operation permission overrides.
    ///   - perCategory: Per-category default permissions.
    public init(
        perOperation: [String: PermissionLevel] = [:],
        perCategory: [OperationCategory: PermissionLevel] = [:]
    ) {
        self.perOperation = perOperation
        self.perCategory = perCategory
    }

    /// Get the effective permission level for a specific operation.
    /// - Parameter operationName: The name of the operation.
    /// - Returns: The effective permission level.
    public func permission(for operationName: String) -> PermissionLevel {
        // First check per-operation overrides
        if let operationPermission = perOperation[operationName] {
            return operationPermission
        }

        // Then check category defaults
        let category = OperationCategory.category(for: operationName)
        if let categoryPermission = perCategory[category] {
            return categoryPermission
        }

        // Fall back to hardcoded defaults
        return Self.defaultPermissions.perCategory[category] ?? .ask
    }

    /// Merge this configuration with overrides.
    /// - Parameter overrides: Configuration to merge on top of this one.
    /// - Returns: A new configuration with overrides applied.
    public func merged(with overrides: PermissionConfiguration) -> PermissionConfiguration {
        var result = self

        for (category, level) in overrides.perCategory {
            result.perCategory[category] = level
        }

        for (operation, level) in overrides.perOperation {
            result.perOperation[operation] = level
        }

        return result
    }

    /// Default permissions: read operations allowed, everything else requires approval.
    public static let defaultPermissions = PermissionConfiguration(
        perOperation: [:],
        perCategory: [
            .read: .allow,
            .write: .ask,
            .execute: .ask,
            .skill: .ask,
        ]
    )
}
