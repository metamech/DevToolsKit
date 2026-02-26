import Foundation
import Observation

/// A single log entry in the DevTools log store.
public struct DevToolsLogEntry: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let level: DevToolsLogLevel
    public let source: String
    public let message: String
    public let metadata: String?

    public init(
        level: DevToolsLogLevel,
        source: String,
        message: String,
        metadata: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.level = level
        self.source = source
        self.message = message
        self.metadata = metadata
    }
}

/// Aggregates log entries into a unified, filterable stream with FIFO capacity management.
@MainActor
@Observable
public final class DevToolsLogStore: Sendable {
    /// All entries (max capacity, FIFO).
    public private(set) var entries: [DevToolsLogEntry] = []

    /// Filter by minimum level.
    public var filterLevel: DevToolsLogLevel = .debug

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

    /// Get the most recent N entries.
    public func recentEntries(_ count: Int = 100) -> [DevToolsLogEntry] {
        Array(entries.suffix(count))
    }
}
