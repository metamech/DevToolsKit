import Testing
import Foundation
@testable import DevToolsKitProcess

@Suite("ProcessResult")
struct ProcessResultTests {

    @Test func succeededWhenExitCodeZero() {
        let result = ProcessResult(exitCode: 0, stdout: "output", stderr: "", duration: 0.5)
        #expect(result.succeeded)
        #expect(result.exitCode == 0)
        #expect(result.stdout == "output")
        #expect(result.stderr == "")
    }

    @Test func failedWhenExitCodeNonZero() {
        let result = ProcessResult(exitCode: 1, stdout: "", stderr: "error", duration: 0.2)
        #expect(!result.succeeded)
        #expect(result.exitCode == 1)
        #expect(result.stderr == "error")
    }

    @Test func hasUniqueIdentifier() {
        let a = ProcessResult(exitCode: 0, stdout: "", stderr: "", duration: 0)
        let b = ProcessResult(exitCode: 0, stdout: "", stderr: "", duration: 0)
        #expect(a.id != b.id)
    }

    @Test func recordsStartedAt() {
        let now = Date()
        let result = ProcessResult(exitCode: 0, stdout: "", stderr: "", duration: 0.1, startedAt: now)
        #expect(result.startedAt == now)
    }
}

@Suite("ProcessExecutor - Synchronous")
struct ProcessExecutorSyncTests {

    @Test func executeSuccess() throws {
        let result = try ProcessExecutor.execute("/bin/echo", arguments: ["hello"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("hello"))
        #expect(result.succeeded)
        #expect(result.duration >= 0)
    }

    @Test func executeWithArguments() throws {
        let result = try ProcessExecutor.execute("/bin/echo", arguments: ["one", "two", "three"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("one"))
        #expect(result.stdout.contains("two"))
        #expect(result.stdout.contains("three"))
    }

    @Test func executeWithStderr() throws {
        let result = try ProcessExecutor.execute("/bin/ls", arguments: ["/nonexistent/path/xyz"])
        #expect(result.exitCode != 0)
        #expect(!result.succeeded)
        #expect(!result.stderr.isEmpty)
    }

    @Test func executeWithWorkingDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let result = try ProcessExecutor.execute("/bin/pwd", workingDirectory: tempDir)
        #expect(result.exitCode == 0)
        #expect(
            result.stdout.contains(tempDir.path)
            || result.stdout.contains("/var")
            || result.stdout.contains("/private")
        )
    }

    @Test func executeInvalidExecutableThrows() {
        #expect(throws: ProcessExecutionError.self) {
            try ProcessExecutor.execute("/nonexistent/command")
        }
    }

    @Test func executeTracksDuration() throws {
        let result = try ProcessExecutor.execute("/bin/sleep", arguments: ["0.1"])
        #expect(result.exitCode == 0)
        #expect(result.duration > 0.05)
        #expect(result.duration < 2.0)
    }
}

@Suite("ProcessExecutor - Async")
struct ProcessExecutorAsyncTests {

    @Test func asyncSuccess() async throws {
        let result = try await ProcessExecutor.executeAsync("/bin/echo", arguments: ["async test"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("async test"))
        #expect(result.succeeded)
    }

    @Test func asyncWithTimeout() async throws {
        let result = try await ProcessExecutor.executeAsync(
            "/bin/echo", arguments: ["quick"], timeout: 5.0
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("quick"))
    }

    @Test func asyncTimeoutEnforcement() async throws {
        let result = try await ProcessExecutor.executeAsync(
            "/bin/sleep", arguments: ["2"], timeout: 0.5
        )
        // Process should be terminated (exit code 15 = SIGTERM)
        #expect(result.exitCode != 0)
        #expect(result.duration < 1.5)
    }

    @Test func asyncNoTimeout() async throws {
        let result = try await ProcessExecutor.executeAsync(
            "/bin/sleep", arguments: ["0.1"], timeout: nil
        )
        #expect(result.exitCode == 0)
        #expect(result.succeeded)
    }

    @Test func asyncWithEnvironment() async throws {
        let customEnv = ["TEST_VAR": "test_value"]
        let result = try await ProcessExecutor.executeAsync(
            "/usr/bin/printenv", arguments: ["TEST_VAR"], environment: customEnv
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("test_value"))
    }

    @Test func asyncCapturesStdout() async throws {
        let result = try await ProcessExecutor.executeAsync(
            "/bin/echo", arguments: ["stdout output"]
        )
        #expect(result.stdout.contains("stdout output"))
        #expect(result.stderr.isEmpty)
    }

    @Test func asyncCapturesStderr() async throws {
        let result = try await ProcessExecutor.executeAsync(
            "/bin/ls", arguments: ["/nonexistent/xyz123"]
        )
        #expect(!result.succeeded)
        #expect(!result.stderr.isEmpty)
    }
}

@Suite("ProcessExecutor - Shell")
struct ProcessExecutorShellTests {

    @Test func shellSimpleCommand() async throws {
        let result = try await ProcessExecutor.executeShell("echo 'shell test'")
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("shell test"))
    }

    @Test func shellWithPipe() async throws {
        let result = try await ProcessExecutor.executeShell("echo 'hello world' | grep 'world'")
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("world"))
    }

    @Test func shellWithRedirection() async throws {
        let result = try await ProcessExecutor.executeShell(
            "echo 'test' > /dev/null && echo 'done'"
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("done"))
    }

    @Test func shellWithVariables() async throws {
        let result = try await ProcessExecutor.executeShell("VAR='value' && echo $VAR")
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("value"))
    }

    @Test func shellWithWorkingDirectory() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let result = try await ProcessExecutor.executeShell("pwd", workingDirectory: tempDir)
        #expect(result.exitCode == 0)
        #expect(
            result.stdout.contains(tempDir.path)
            || result.stdout.contains("/var")
            || result.stdout.contains("/private")
        )
    }

    @Test func shellWithTimeout() async throws {
        let result = try await ProcessExecutor.executeShell("sleep 2", timeout: 0.5)
        #expect(result.exitCode != 0)
        #expect(result.duration < 1.5)
    }

    @Test func shellFailedCommand() async throws {
        let result = try await ProcessExecutor.executeShell("exit 42")
        #expect(result.exitCode == 42)
        #expect(!result.succeeded)
    }

    @Test func shellMultipleCommands() async throws {
        let result = try await ProcessExecutor.executeShell(
            "echo 'one' && echo 'two' && echo 'three'"
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("one"))
        #expect(result.stdout.contains("two"))
        #expect(result.stdout.contains("three"))
    }

    @Test func shellConditionalExecution() async throws {
        let result = try await ProcessExecutor.executeShell("false || echo 'fallback'")
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("fallback"))
    }
}

@Suite("ProcessExecutor - Format Output")
struct ProcessExecutorFormatOutputTests {

    @Test func stdoutOnly() {
        let result = ProcessResult(exitCode: 0, stdout: "output", stderr: "", duration: 0.1)
        let formatted = ProcessExecutor.formatOutput(result)
        #expect(formatted == "output")
    }

    @Test func stderrOnly() {
        let result = ProcessResult(exitCode: 1, stdout: "", stderr: "error", duration: 0.1)
        let formatted = ProcessExecutor.formatOutput(result)
        #expect(formatted == "error")
    }

    @Test func bothStreams() {
        let result = ProcessResult(exitCode: 0, stdout: "output", stderr: "warning", duration: 0.1)
        let formatted = ProcessExecutor.formatOutput(result)
        #expect(formatted == "output\nwarning")
    }

    @Test func excludeStderr() {
        let result = ProcessResult(exitCode: 0, stdout: "output", stderr: "error", duration: 0.1)
        let formatted = ProcessExecutor.formatOutput(result, includeStderr: false)
        #expect(formatted == "output")
        #expect(!formatted.contains("error"))
    }

    @Test func emptyOutput() {
        let result = ProcessResult(exitCode: 0, stdout: "", stderr: "", duration: 0.1)
        let formatted = ProcessExecutor.formatOutput(result)
        #expect(formatted == "")
    }
}

@Suite("ProcessExecutor - Edge Cases")
struct ProcessExecutorEdgeCaseTests {

    @Test func largeOutput() async throws {
        let result = try await ProcessExecutor.executeAsync(
            "/usr/bin/seq", arguments: ["1", "10000"]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.count > 10000)
        #expect(result.stdout.contains("10000"))
    }

    @Test func unicodeOutput() async throws {
        let result = try await ProcessExecutor.executeAsync(
            "/bin/echo", arguments: ["Hello \u{4e16}\u{754c} \u{1f30d}"]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\u{4e16}\u{754c}"))
    }

    @Test func specialCharacters() async throws {
        let result = try await ProcessExecutor.executeAsync(
            "/bin/echo", arguments: ["$#@!%^&*()"]
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("$#@!%^&*()"))
    }

    @Test func sequentialCalls() async throws {
        for i in 1...5 {
            let result = try await ProcessExecutor.executeAsync(
                "/bin/echo", arguments: ["test \(i)"]
            )
            #expect(result.exitCode == 0)
            #expect(result.stdout.contains("test \(i)"))
        }
    }

    @Test func concurrentCalls() async throws {
        await withTaskGroup(of: Bool.self) { group in
            for i in 1...5 {
                group.addTask {
                    do {
                        let result = try await ProcessExecutor.executeAsync(
                            "/bin/echo", arguments: ["concurrent \(i)"]
                        )
                        return result.exitCode == 0
                    } catch {
                        return false
                    }
                }
            }

            var successCount = 0
            for await success in group {
                if success { successCount += 1 }
            }

            #expect(successCount == 5)
        }
    }

    @Test func emptyStdoutStderr() async throws {
        let result = try await ProcessExecutor.executeAsync("/usr/bin/true")
        #expect(result.exitCode == 0)
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.isEmpty)
    }

    @Test func durationAccuracy() async throws {
        let sleepDuration = 0.2
        let result = try await ProcessExecutor.executeAsync(
            "/bin/sleep", arguments: [String(sleepDuration)]
        )
        #expect(result.duration > sleepDuration * 0.8)
        #expect(result.duration < sleepDuration * 5.0)
    }
}

@Suite("ProcessExecutionError")
struct ProcessExecutionErrorTests {

    @Test func timeoutErrorDescription() {
        let error = ProcessExecutionError.timeout(5.0)
        #expect(error.localizedDescription.contains("timed out"))
        #expect(error.localizedDescription.contains("5.0"))
    }

    @Test func executionFailedDescription() {
        let error = ProcessExecutionError.executionFailed("file not found")
        #expect(error.localizedDescription.contains("file not found"))
    }
}
