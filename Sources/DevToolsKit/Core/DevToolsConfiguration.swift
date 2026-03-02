import Foundation

/// Global display mode for all developer tool panels.
///
/// Controls how panels are presented when opened. Individual panels can be
/// "popped out" to standalone windows without changing the global mode.
///
/// Since 0.4.0
public enum DevToolsDisplayMode: String, Codable, Sendable, CaseIterable {
    /// All panels appear in a split-view dock attached to the app content.
    case docked
    /// All panels share a single tabbed `NSWindow`.
    case windowed
    /// Each panel opens in its own standalone `NSWindow`.
    case separateWindows
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
