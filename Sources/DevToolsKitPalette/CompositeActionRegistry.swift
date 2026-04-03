/// Combines a primary ``ActionRegistryProtocol`` with a secondary (global) registry
/// so that queries see both sets of actions.
///
/// Writes (register/unregister/recordUsage) go to the primary registry.
/// Reads (allActions/recentActionIds) merge both registries, deduplicating
/// by action ID with the primary taking precedence.
@MainActor
public final class CompositeActionRegistry: ActionRegistryProtocol {

    private let primary: ActionRegistryProtocol
    private let global: ActionRegistryProtocol

    /// Creates a composite registry.
    ///
    /// - Parameters:
    ///   - primary: The per-context (e.g. per-window) registry. Writes target this.
    ///   - global: The app-wide registry. Provides fallback actions for reads.
    public init(primary: ActionRegistryProtocol, global: ActionRegistryProtocol) {
        self.primary = primary
        self.global = global
    }

    public func register(_ action: PaletteAction) {
        primary.register(action)
    }

    public func register(_ actions: [PaletteAction]) {
        primary.register(actions)
    }

    public func unregister(id: String) {
        primary.unregister(id: id)
    }

    public func allActions(filter: String?) -> [PaletteAction] {
        let primaryActions = primary.allActions(filter: filter)
        let primaryIds = Set(primaryActions.map(\.id))
        let globalActions = global.allActions(filter: filter)
            .filter { !primaryIds.contains($0.id) }
        return primaryActions + globalActions
    }

    public var recentActionIds: [String] {
        primary.recentActionIds
    }

    public func recordUsage(actionId: String) {
        primary.recordUsage(actionId: actionId)
    }
}
