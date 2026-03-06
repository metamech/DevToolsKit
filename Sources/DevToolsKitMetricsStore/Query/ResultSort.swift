import Foundation

/// Sort order for database query results.
///
/// > Since: 0.3.0
public enum ResultSort: Sendable {
    /// Sort by value ascending.
    case valueAscending
    /// Sort by value descending.
    case valueDescending
    /// Sort by label ascending.
    case labelAscending
    /// Sort by time ascending.
    case timeAscending
    /// Sort by time descending.
    case timeDescending
}
