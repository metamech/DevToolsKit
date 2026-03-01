import Foundation

/// Errors that can occur during process execution.
///
/// Since 0.4.0
public enum ProcessExecutionError: Error, LocalizedError, Sendable {
    /// The process was terminated because it exceeded the specified timeout.
    case timeout(TimeInterval)

    /// The process could not be started.
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .timeout(let seconds):
            return "Process timed out after \(String(format: "%.1f", seconds)) seconds"
        case .executionFailed(let reason):
            return "Process execution failed: \(reason)"
        }
    }
}
