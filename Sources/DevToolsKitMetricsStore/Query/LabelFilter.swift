import Foundation

/// Filter strategy for matching metric labels.
///
/// > Since: 0.3.0
public enum LabelFilter: Sendable {
    /// Exact label match.
    case exact(String)
    /// Label starts with the given prefix.
    case prefix(String)
    /// Label contains the given substring.
    case contains(String)

    /// Returns `true` if the given label matches this filter.
    func matches(_ label: String) -> Bool {
        switch self {
        case .exact(let value): label == value
        case .prefix(let value): label.hasPrefix(value)
        case .contains(let value): label.contains(value)
        }
    }
}
