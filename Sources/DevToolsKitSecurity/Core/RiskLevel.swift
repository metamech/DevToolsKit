import Foundation

/// Risk level for an operation request.
///
/// Since 0.4.0
public enum RiskLevel: String, Sendable, Codable, Hashable {
    /// Low risk operation (e.g., reading a single file).
    case low
    /// Medium risk operation (e.g., writing to a file).
    case medium
    /// High risk operation (e.g., executing shell commands, deleting files).
    case high
}
