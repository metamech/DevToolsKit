import Foundation
import Observation

/// A single log entry captured by the DevTools log store.
public struct DevToolsLogEntry: Identifiable, Sendable {
    /// Unique identifier for this entry.
    public let id: UUID
    /// When the entry was created.
    public let timestamp: Date
    /// Severity level.
    public let level: DevToolsLogLevel
    /// Logger label or subsystem name.
    public let source: String
    /// The log message text.
    public let message: String
    /// Optional key-value metadata string (e.g., `"requestID=abc traceID=123"`).
    public let metadata: String?

    /// - Parameters:
    ///   - level: Severity level.
    ///   - source: Logger label or subsystem name.
    ///   - message: The log message text.
    ///   - metadata: Optional metadata string.
    ///   - timestamp: Entry timestamp; defaults to now.
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
