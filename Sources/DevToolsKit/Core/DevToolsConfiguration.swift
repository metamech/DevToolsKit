import Foundation

/// Display mode for a panel.
public enum PanelDisplayMode: String, Codable, Sendable {
    case standalone
    case tabbed
    case docked
}

/// Dock position relative to the main app content.
public enum DockPosition: String, Codable, Sendable, CaseIterable {
    case bottom
    case right
    case left
}

/// Log level filter for developer tools.
public enum DevToolsLogLevel: String, CaseIterable, Sendable, Codable, Comparable {
    case debug, info, warning, error

    public var displayName: String {
        rawValue.capitalized
    }

    public static func < (lhs: DevToolsLogLevel, rhs: DevToolsLogLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    private var sortOrder: Int {
        switch self {
        case .debug: 0
        case .info: 1
        case .warning: 2
        case .error: 3
        }
    }
}
