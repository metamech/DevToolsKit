import Foundation

/// Categories of operations for permission management.
///
/// Provides a configurable mapping from operation names to categories.
///
/// Since 0.4.0
public enum OperationCategory: String, Codable, Sendable, Hashable {
    /// Read-only operations.
    case read
    /// Write operations.
    case write
    /// Command execution operations.
    case execute
    /// Skill or plugin execution.
    case skill

    /// Default mapping from operation names to categories.
    ///
    /// Maps common names like "read", "glob", "grep" to `.read`,
    /// "write", "edit" to `.write`, "bash" to `.execute`.
    /// Unknown names map to `.skill`.
    public static let defaultMapping: [String: OperationCategory] = [
        "read": .read,
        "glob": .read,
        "grep": .read,
        "write": .write,
        "edit": .write,
        "bash": .execute,
    ]

    /// Determine the category for a given operation name using the default mapping.
    /// - Parameter operationName: The name of the operation (case-insensitive).
    /// - Returns: The category this operation belongs to.
    public static func category(for operationName: String) -> OperationCategory {
        category(for: operationName, using: defaultMapping)
    }

    /// Determine the category for a given operation name using a custom mapping.
    /// - Parameters:
    ///   - operationName: The name of the operation (case-insensitive).
    ///   - mapping: Custom mapping dictionary from operation names to categories.
    /// - Returns: The category this operation belongs to, or `.skill` if not found.
    public static func category(
        for operationName: String,
        using mapping: [String: OperationCategory]
    ) -> OperationCategory {
        mapping[operationName.lowercased()] ?? .skill
    }
}
