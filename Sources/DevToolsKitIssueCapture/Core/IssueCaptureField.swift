/// Defines the type of input field for expected-state capture.
///
/// Since 0.5.0
public enum IssueCaptureField: Sendable, Identifiable {
    /// Free-text input field.
    case text(id: String, label: String, placeholder: String)

    /// Single-selection from a list of options.
    case quickSelect(id: String, label: String, options: [String])

    /// Multi-selection from a list of options.
    case multiSelect(id: String, label: String, options: [String])

    /// The field's unique identifier.
    public var id: String {
        switch self {
        case .text(let id, _, _): id
        case .quickSelect(let id, _, _): id
        case .multiSelect(let id, _, _): id
        }
    }

    /// The field's display label.
    public var label: String {
        switch self {
        case .text(_, let label, _): label
        case .quickSelect(_, let label, _): label
        case .multiSelect(_, let label, _): label
        }
    }
}
