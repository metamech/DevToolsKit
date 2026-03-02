import DevToolsKit
import Foundation
import Observation

/// Aggregates log entries into a unified, filterable stream with FIFO capacity management.
@MainActor
@Observable
public final class DevToolsLogStore: Sendable {
    /// All entries (max capacity, FIFO).
    public private(set) var entries: [DevToolsLogEntry] = []

    /// Filter by minimum level.
    public var filterLevel: DevToolsLogLevel = .trace

    /// Filter by source tag (nil = all).
    public var filterSource: String?

    /// Search text filter.
    public var searchText: String = ""

    /// All unique source tags seen.
    public var knownSources: [String] {
        Array(Set(entries.map(\.source))).sorted()
    }

    /// Filtered entries based on current filters.
    public var filteredEntries: [DevToolsLogEntry] {
        entries.filter { entry in
            entry.level >= filterLevel
                && (filterSource == nil || entry.source == filterSource)
                && (searchText.isEmpty || entry.message.localizedCaseInsensitiveContains(searchText))
        }
    }

    /// Maximum number of entries before FIFO trimming.
    public let maxEntries: Int

    /// - Parameter maxEntries: FIFO capacity; oldest entries are trimmed when exceeded. Defaults to 5000.
    public init(maxEntries: Int = 5000) {
        self.maxEntries = maxEntries
    }

    /// Append a log entry, enforcing FIFO cap.
    public func append(_ entry: DevToolsLogEntry) {
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    /// Clear all entries.
    public func clear() {
        entries.removeAll()
    }

    /// Get the most recent entries (used by diagnostic export).
    ///
    /// - Parameter count: Maximum number of entries to return; defaults to 100.
    /// - Returns: The last `count` entries in chronological order.
    public func recentEntries(_ count: Int = 100) -> [DevToolsLogEntry] {
        Array(entries.suffix(count))
    }
}
