#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import DevToolsKit
import Foundation

/// Formatting utilities for log entries — plain text and JSON.
///
/// Since 0.6.0
public enum LogEntryFormatter: Sendable {
    private static nonisolated(unsafe) let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Three-letter level code matching the log panel badge text.
    private static func levelCode(_ level: DevToolsLogLevel) -> String {
        switch level {
        case .trace: "TRC"
        case .debug: "DBG"
        case .info: "INF"
        case .warning: "WRN"
        case .error: "ERR"
        }
    }

    /// Format a single entry as a human-readable text line.
    ///
    /// Format: `"2026-03-12T10:30:45.123Z  INF  [source]  message"`
    /// with metadata on a continuation line if present.
    ///
    /// - Parameter entry: The log entry to format.
    /// - Returns: A formatted text representation.
    public static func formatLine(_ entry: DevToolsLogEntry) -> String {
        let ts = isoFormatter.string(from: entry.timestamp)
        let lvl = levelCode(entry.level)
        var line = "\(ts)  \(lvl)  [\(entry.source)]  \(entry.message)"
        if let metadata = entry.metadata {
            line += "\n                              \(metadata)"
        }
        return line
    }

    /// Format multiple entries as newline-separated text.
    ///
    /// - Parameter entries: The entries to format.
    /// - Returns: All entries joined by newlines, or empty string if none.
    public static func formatText(_ entries: [DevToolsLogEntry]) -> String {
        entries.map { formatLine($0) }.joined(separator: "\n")
    }

    /// Encode entries as a pretty-printed JSON array.
    ///
    /// - Parameter entries: The entries to encode.
    /// - Returns: UTF-8 JSON string.
    /// - Throws: If encoding fails.
    public static func formatJSON(_ entries: [DevToolsLogEntry]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entries)
        return String(decoding: data, as: UTF8.self)
    }

    /// Copy text to the system clipboard.
    ///
    /// Available on macOS and iOS; unavailable on tvOS and watchOS.
    ///
    /// - Parameter text: The string to place on the clipboard.
    #if !os(tvOS) && !os(watchOS)
    @MainActor
    public static func copyToClipboard(_ text: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #elseif canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
    #endif
}
