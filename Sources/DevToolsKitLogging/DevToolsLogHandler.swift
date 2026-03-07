import DevToolsKit
import Foundation
import Logging
import os

/// A swift-log `LogHandler` that feeds log entries into a `DevToolsLogStore`.
///
/// Install it as the bootstrap handler or as a multiplexed handler:
///
/// ```swift
/// let logStore = DevToolsLogStore()
/// LoggingSystem.bootstrap { label in
///     DevToolsLogHandler(label: label, store: logStore)
/// }
/// ```
///
/// Or use it alongside other handlers with `MultiplexLogHandler`.
///
/// By default, all log messages are also forwarded to `os.Logger` so they
/// appear in Console.app. Pass `osLogForwarding: false` to disable.
public struct DevToolsLogHandler: LogHandler, @unchecked Sendable {
    public var logLevel: Logging.Logger.Level = .trace
    public var metadata: Logging.Logger.Metadata = [:]

    private let label: String
    private let store: DevToolsLogStore
    private let osLogger: os.Logger?

    /// - Parameters:
    ///   - label: The logger label (used as the entry's `source`).
    ///   - store: The shared log store to append entries to.
    ///   - osLogForwarding: Whether to forward log messages to `os.Logger` (default: `true`).
    ///
    /// Since 0.4.0 — `osLogForwarding` parameter added.
    public init(label: String, store: DevToolsLogStore, osLogForwarding: Bool = true) {
        self.label = label
        self.store = store
        self.osLogger = osLogForwarding
            ? os.Logger(
                subsystem: Bundle.main.bundleIdentifier ?? "DevToolsKit",
                category: label
            )
            : nil
    }

    public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    public func log(
        level: Logging.Logger.Level,
        message: Logging.Logger.Message,
        metadata: Logging.Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let devLevel = mapLevel(level)
        let mergedMetadata = self.metadata.merging(metadata ?? [:]) { _, new in new }
        let metadataString: String? =
            mergedMetadata.isEmpty
            ? nil
            : mergedMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: " ")

        let entry = DevToolsLogEntry(
            level: devLevel,
            source: label,
            message: "\(message)",
            metadata: metadataString
        )

        Task { @MainActor in
            store.append(entry)
        }

        if let osLogger {
            let messageString = message.description
            osLogger.log(level: mapOSLogType(level), "\(messageString, privacy: .public)")
        }
    }

    private func mapLevel(_ level: Logging.Logger.Level) -> DevToolsLogLevel {
        switch level {
        case .trace:
            return .trace
        case .debug:
            return .debug
        case .info, .notice:
            return .info
        case .warning:
            return .warning
        case .error, .critical:
            return .error
        }
    }

    private func mapOSLogType(_ level: Logging.Logger.Level) -> OSLogType {
        switch level {
        case .trace, .debug:
            return .debug
        case .info, .notice:
            return .info
        case .warning:
            return .default
        case .error, .critical:
            return .error
        }
    }
}
