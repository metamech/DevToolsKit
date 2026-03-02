import Foundation

/// How a panel is displayed: as its own window, in the shared tabbed window, or docked to the app content.
public enum PanelDisplayMode: String, Codable, Sendable {
    /// Panel opens in its own standalone `NSWindow`.
    case standalone
    /// Panel opens as a tab in the shared tabbed window.
    case tabbed
    /// Panel opens in the resizable dock attached to the app content.
    case docked
}

/// Edge where the dock attaches to the main app content.
public enum DockPosition: String, Codable, Sendable, CaseIterable {
    /// Dock below the main content (horizontal split).
    case bottom
    /// Dock to the right (vertical split).
    case right
    /// Dock to the left (vertical split).
    case left
}

/// Severity levels for log entries, ordered from least to most severe.
///
/// Conforms to `Comparable` so you can filter with `entry.level >= .warning`.
public enum DevToolsLogLevel: String, CaseIterable, Sendable, Codable, Comparable {
    case trace, debug, info, warning, error

    /// Human-readable name (e.g., "Warning").
    public var displayName: String {
        rawValue.capitalized
    }

    public static func < (lhs: DevToolsLogLevel, rhs: DevToolsLogLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    private var sortOrder: Int {
        switch self {
        case .trace: -1
        case .debug: 0
        case .info: 1
        case .warning: 2
        case .error: 3
        }
    }
}
