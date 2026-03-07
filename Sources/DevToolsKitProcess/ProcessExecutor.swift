#if os(macOS)
import Foundation
import os

/// Utility for executing external processes with consistent error handling and timeout support.
///
/// `ProcessExecutor` provides static methods for running external commands synchronously
/// or asynchronously, with optional timeout enforcement.
///
/// ```swift
/// // Synchronous execution
/// let result = try ProcessExecutor.execute("/usr/bin/git", arguments: ["status"])
///
/// // Asynchronous with timeout
/// let result = try await ProcessExecutor.executeAsync(
///     "/usr/bin/swift", arguments: ["build"], timeout: 120
/// )
///
/// // Shell command with pipes
/// let result = try await ProcessExecutor.executeShell("ls -la | grep .swift")
/// ```
///
/// Since 0.4.0
public struct ProcessExecutor: Sendable {

    private static let logger = Logger(
        subsystem: "com.devtoolskit.process",
        category: "ProcessExecutor"
    )

    // MARK: - Synchronous Execution

    /// Executes a command synchronously.
    /// - Parameters:
    ///   - executable: Path to the executable.
    ///   - arguments: Command arguments.
    ///   - workingDirectory: Working directory (optional).
    ///   - environment: Environment variables (optional, inherits current if nil).
    /// - Returns: A ``ProcessResult`` with exit code and output.
    /// - Throws: ``ProcessExecutionError/executionFailed(_:)`` if the process cannot start.
    public static func execute(
        _ executable: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        environment: [String: String]? = nil
    ) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        if let workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }

        if let environment {
            process.environment = environment
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let startTime = Date()

        do {
            try process.run()
        } catch {
            throw ProcessExecutionError.executionFailed(error.localizedDescription)
        }

        process.waitUntilExit()

        let duration = Date().timeIntervalSince(startTime)

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: stdout,
            stderr: stderr,
            duration: duration,
            startedAt: startTime
        )
    }

    // MARK: - Asynchronous Execution with Timeout

    /// Executes a command asynchronously with optional timeout support.
    /// - Parameters:
    ///   - executable: Path to the executable.
    ///   - arguments: Command arguments.
    ///   - workingDirectory: Working directory (optional).
    ///   - environment: Environment variables (optional, inherits current if nil).
    ///   - timeout: Maximum execution time in seconds (`nil` = no timeout).
    /// - Returns: A ``ProcessResult`` with exit code and output.
    /// - Throws: ``ProcessExecutionError/executionFailed(_:)`` if the process cannot start.
    public static func executeAsync(
        _ executable: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        environment: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        if let workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }

        if let environment {
            process.environment = environment
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let startTime = Date()

        do {
            try process.run()
        } catch {
            throw ProcessExecutionError.executionFailed(error.localizedDescription)
        }

        // Set up timeout if specified
        var timeoutTask: Task<Void, Never>?
        if let timeout {
            timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if process.isRunning {
                    logger.warning("Terminating process due to timeout (\(timeout)s)")
                    process.terminate()
                }
            }
        }

        // Wait for process to finish
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }

        // Cancel timeout task if process finished
        timeoutTask?.cancel()

        let duration = Date().timeIntervalSince(startTime)

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: stdout,
            stderr: stderr,
            duration: duration,
            startedAt: startTime
        )
    }

    // MARK: - Shell Command Execution

    /// Executes a shell command via `/bin/bash`.
    /// - Parameters:
    ///   - command: The shell command to execute.
    ///   - workingDirectory: Working directory (optional).
    ///   - timeout: Maximum execution time in seconds (`nil` = no timeout).
    /// - Returns: A ``ProcessResult`` with exit code and output.
    /// - Throws: ``ProcessExecutionError/executionFailed(_:)`` if the process cannot start.
    public static func executeShell(
        _ command: String,
        workingDirectory: URL? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> ProcessResult {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

        return try await executeAsync(
            "/bin/bash",
            arguments: ["-c", command],
            workingDirectory: workingDirectory,
            environment: environment,
            timeout: timeout
        )
    }

    // MARK: - Output Formatting

    /// Formats process output for display, combining stdout and stderr.
    /// - Parameters:
    ///   - result: The process result.
    ///   - includeStderr: Whether to include stderr in output (default: `true`).
    /// - Returns: Formatted output string.
    public static func formatOutput(_ result: ProcessResult, includeStderr: Bool = true) -> String {
        var output = result.stdout

        if includeStderr && !result.stderr.isEmpty {
            if !output.isEmpty {
                output += "\n"
            }
            output += result.stderr
        }

        return output
    }
}
#endif
