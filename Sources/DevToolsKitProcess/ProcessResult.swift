import Foundation

/// The result of an external process execution.
///
/// Contains the exit code, captured stdout/stderr output, timing information,
/// and a unique identifier for tracking.
///
/// Since 0.4.0
public struct ProcessResult: Sendable, Identifiable {
    /// Unique identifier for this result.
    public let id: UUID

    /// The process exit code. A value of `0` typically indicates success.
    public let exitCode: Int32

    /// Standard output captured from the process.
    public let stdout: String

    /// Standard error captured from the process.
    public let stderr: String

    /// Wall-clock duration of the process execution in seconds.
    public let duration: TimeInterval

    /// When the process started executing.
    public let startedAt: Date

    /// Whether the process exited with code `0`.
    public var succeeded: Bool {
        exitCode == 0
    }

    /// Creates a new process result.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - exitCode: The process exit code.
    ///   - stdout: Captured standard output.
    ///   - stderr: Captured standard error.
    ///   - duration: Execution duration in seconds.
    ///   - startedAt: When the process started (defaults to now minus duration).
    public init(
        id: UUID = UUID(),
        exitCode: Int32,
        stdout: String,
        stderr: String,
        duration: TimeInterval,
        startedAt: Date = Date()
    ) {
        self.id = id
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.duration = duration
        self.startedAt = startedAt
    }
}
