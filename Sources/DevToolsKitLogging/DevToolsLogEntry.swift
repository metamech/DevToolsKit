import DevToolsKit
import Foundation

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
