import Foundation

/// A fluent, value-type builder for ``PaletteAction``.
///
/// Obtain a builder via ``PaletteAction/build()``, chain the setters, and finish
/// with ``build()``. Required fields are `id`, `title`, `category`, and `execute`
/// (or ``drillDown()``). Missing any required field triggers `preconditionFailure`.
///
/// ```swift
/// PaletteAction.build()
///     .id("file.new")
///     .titled("New File")
///     .category(.general)
///     .icon("plus.rectangle")
///     .keyed("⌘N")
///     .execute { ... }
///     .build()
/// ```
@MainActor
public struct PaletteActionBuilder {
    private var _id: String?
    private var _title: String?
    private var _subtitle: String?
    private var _category: PaletteActionCategory?
    private var _iconName: String?
    private var _keyboardShortcut: String?
    private var _isEnabled: (@MainActor () -> Bool)?
    private var _execute: (@MainActor () async -> Void)?
    private var _children: [PaletteAction]?

    public init() {}

    // MARK: - Required fields

    public func id(_ id: String) -> PaletteActionBuilder {
        var copy = self; copy._id = id; return copy
    }

    public func titled(_ title: String) -> PaletteActionBuilder {
        var copy = self; copy._title = title; return copy
    }

    public func category(_ category: PaletteActionCategory) -> PaletteActionBuilder {
        var copy = self; copy._category = category; return copy
    }

    public func execute(_ action: @escaping @MainActor () async -> Void) -> PaletteActionBuilder {
        var copy = self; copy._execute = action; return copy
    }

    // MARK: - Optional fields

    public func subtitle(_ subtitle: String) -> PaletteActionBuilder {
        var copy = self; copy._subtitle = subtitle; return copy
    }

    public func icon(_ name: String) -> PaletteActionBuilder {
        var copy = self; copy._iconName = name; return copy
    }

    public func keyed(_ shortcut: String) -> PaletteActionBuilder {
        var copy = self; copy._keyboardShortcut = shortcut; return copy
    }

    public func enabled(when predicate: @escaping @MainActor () -> Bool) -> PaletteActionBuilder {
        var copy = self; copy._isEnabled = predicate; return copy
    }

    public func children(_ children: [PaletteAction]) -> PaletteActionBuilder {
        var copy = self; copy._children = children; return copy
    }

    /// Sets execute to a no-op — for drill-down parent actions that only navigate
    /// into children.
    public func drillDown() -> PaletteActionBuilder {
        var copy = self; copy._execute = { }; return copy
    }

    // MARK: - Terminal

    public func build() -> PaletteAction {
        guard let id = _id else {
            preconditionFailure("PaletteActionBuilder: id is required")
        }
        guard let title = _title else {
            preconditionFailure("PaletteActionBuilder: title is required")
        }
        guard let category = _category else {
            preconditionFailure("PaletteActionBuilder: category is required")
        }
        guard let execute = _execute else {
            preconditionFailure("PaletteActionBuilder: execute is required (use .drillDown() for parent actions)")
        }

        return PaletteAction(
            id: id,
            title: title,
            subtitle: _subtitle,
            category: category,
            iconName: _iconName,
            keyboardShortcut: _keyboardShortcut,
            isEnabled: _isEnabled ?? { true },
            execute: execute,
            children: _children
        )
    }
}

// MARK: - PaletteAction entry point

extension PaletteAction {
    /// Returns a fresh fluent builder for constructing a ``PaletteAction``.
    public static func build() -> PaletteActionBuilder {
        PaletteActionBuilder()
    }
}

// MARK: - Convenience factories

extension PaletteAction {
    /// Creates a toggle action with a standard "Currently: On/Off" subtitle.
    public static func toggle(
        id: String,
        title: String,
        icon: String? = nil,
        current: Bool,
        category: PaletteActionCategory = .settings,
        action: @escaping @MainActor () async -> Void
    ) -> PaletteAction {
        var builder = PaletteAction.build()
            .id(id)
            .titled(title)
            .subtitle("Currently: \(current ? "On" : "Off")")
            .category(category)
            .execute(action)
        if let icon {
            builder = builder.icon(icon)
        }
        return builder.build()
    }
}
