import Foundation
import DevToolsKit
import Observation

/// A concrete ``ActionRegistryProtocol`` implementation that stores actions
/// in memory and supports fuzzy-filtered retrieval via ``FuzzyMatcher``.
///
/// Actions are stored by `id` and upserted on registration. Fuzzy matching
/// is applied across title, subtitle, and category display name, returning
/// results sorted by best match score.
@MainActor @Observable
public final class ActionRegistry: ActionRegistryProtocol {

    private var actions: [String: PaletteAction] = [:]
    private let defaults: UserDefaults
    private let recentsKey: String
    private let maxRecents: Int

    /// Creates an action registry.
    ///
    /// - Parameters:
    ///   - defaults: UserDefaults store for recent action IDs.
    ///   - recentsKey: The UserDefaults key for storing recent action IDs.
    ///   - maxRecents: Maximum number of recent actions to track.
    public init(
        defaults: UserDefaults = .standard,
        recentsKey: String = "devtools.palette.recentActions",
        maxRecents: Int = 10
    ) {
        self.defaults = defaults
        self.recentsKey = recentsKey
        self.maxRecents = maxRecents
    }

    // MARK: - Registration

    public func register(_ action: PaletteAction) {
        actions[action.id] = action
    }

    public func register(_ actions: [PaletteAction]) {
        for action in actions {
            self.actions[action.id] = action
        }
    }

    public func unregister(id: String) {
        actions.removeValue(forKey: id)
    }

    // MARK: - Querying

    public func allActions(filter: String?) -> [PaletteAction] {
        let enabled = actions.values.filter { $0.isEnabled() }

        guard let filter, !filter.isEmpty else {
            return enabled.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }

        return enabled.compactMap { action -> (PaletteAction, Int)? in
            let titleMatch = FuzzyMatcher.match(query: filter, against: action.title)
            let subtitleMatch = action.subtitle.flatMap { FuzzyMatcher.match(query: filter, against: $0) }
            let categoryMatch = FuzzyMatcher.match(query: filter, against: action.category.displayName)

            let bestScore = [titleMatch?.score, subtitleMatch?.score, categoryMatch?.score]
                .compactMap { $0 }
                .max()

            guard let score = bestScore else { return nil }
            return (action, score)
        }
        .sorted { $0.1 > $1.1 }
        .map(\.0)
    }

    // MARK: - Recents

    public var recentActionIds: [String] {
        defaults.stringArray(forKey: recentsKey) ?? []
    }

    public func recordUsage(actionId: String) {
        var recents = recentActionIds.filter { $0 != actionId }
        recents.insert(actionId, at: 0)
        if recents.count > maxRecents {
            recents = Array(recents.prefix(maxRecents))
        }
        defaults.set(recents, forKey: recentsKey)
    }
}
