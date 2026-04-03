import Foundation

/// A category for grouping palette actions.
///
/// Apps define their own categories by extending this type or using the
/// built-in defaults. Each category has a display name and an SF Symbol icon.
public struct PaletteActionCategory: Hashable, Sendable {
    /// The raw identifier for the category.
    public let rawValue: String

    /// User-facing display name.
    public let displayName: String

    /// SF Symbol name for the category icon.
    public let systemImage: String

    public init(rawValue: String, displayName: String, systemImage: String) {
        self.rawValue = rawValue
        self.displayName = displayName
        self.systemImage = systemImage
    }
}

// MARK: - Built-in Categories

extension PaletteActionCategory {
    public static let general = PaletteActionCategory(rawValue: "general", displayName: "General", systemImage: "square.grid.2x2")
    public static let settings = PaletteActionCategory(rawValue: "settings", displayName: "Settings", systemImage: "gear")
    public static let navigation = PaletteActionCategory(rawValue: "navigation", displayName: "Navigation", systemImage: "sidebar.left")
    public static let developer = PaletteActionCategory(rawValue: "developer", displayName: "Developer", systemImage: "wrench.and.screwdriver")
}

/// An action that can appear in a command palette.
///
/// Each action has a unique `id`, a `title` for display, an optional `subtitle`,
/// a `category` for grouping, and an async `execute` closure. Actions can be
/// hierarchical via the `children` property.
///
/// Use ``PaletteActionBuilder`` for fluent construction.
@MainActor
public struct PaletteAction: Identifiable {
    public nonisolated let id: String
    public let title: String
    public let subtitle: String?
    public let category: PaletteActionCategory
    public let iconName: String?
    public let keyboardShortcut: String?
    public let isEnabled: @MainActor () -> Bool
    public let execute: @MainActor () async -> Void
    public let children: [PaletteAction]?

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        category: PaletteActionCategory,
        iconName: String? = nil,
        keyboardShortcut: String? = nil,
        isEnabled: @escaping @MainActor () -> Bool = { true },
        execute: @escaping @MainActor () async -> Void,
        children: [PaletteAction]? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.iconName = iconName
        self.keyboardShortcut = keyboardShortcut
        self.isEnabled = isEnabled
        self.execute = execute
        self.children = children
    }
}
