import Foundation

/// Protocol for action registries that store and query ``PaletteAction``s.
///
/// Conforming types manage a collection of actions and support fuzzy-filtered
/// retrieval. The ``CompositeActionRegistry`` combines multiple registries
/// (e.g. per-window and global) into a single view.
@MainActor
public protocol ActionRegistryProtocol: AnyObject {
    /// Register a single action. Upserts by `id`.
    func register(_ action: PaletteAction)

    /// Register multiple actions. Upserts by `id`.
    func register(_ actions: [PaletteAction])

    /// Remove a previously registered action by `id`.
    func unregister(id: String)

    /// Returns all enabled actions, optionally filtered by a fuzzy search query.
    func allActions(filter: String?) -> [PaletteAction]

    /// Recently used action IDs, most recent first.
    var recentActionIds: [String] { get }

    /// Record that an action was used, updating the recents list.
    func recordUsage(actionId: String)
}
