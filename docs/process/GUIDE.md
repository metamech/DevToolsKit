[< Core](../core/QUICK_START.md) | [Index](../INDEX.md) | [API >](API.md)

# DevToolsKitProcess Guide

Process execution utilities for running external commands with timeout support.

## Setup

Add `DevToolsKitProcess` to your target:

```swift
.product(name: "DevToolsKitProcess", package: "DevToolsKit")
```

```swift
import DevToolsKitProcess
```

No additional configuration needed — `ProcessExecutor` uses static methods.

## Synchronous Execution

Run a command and wait for it to complete:

```swift
let result = try ProcessExecutor.execute(
    "/usr/bin/git",
    arguments: ["status"],
    workingDirectory: projectURL
)

if result.succeeded {
    print(result.stdout)
} else {
    print("Error: \(result.stderr)")
}
```

## Async Execution with Timeout

Run a command asynchronously with optional timeout:

```swift
let result = try await ProcessExecutor.executeAsync(
    "/usr/bin/swift",
    arguments: ["build"],
    workingDirectory: projectURL,
    timeout: 120  // seconds
)

print("Build took \(result.duration)s")
```

If the process exceeds the timeout, it is terminated via `SIGTERM`.

## Shell Commands

Execute shell commands with pipes, redirections, and variables:

```swift
let result = try await ProcessExecutor.executeShell(
    "git log --oneline | head -5",
    workingDirectory: projectURL
)
```

Shell commands run via `/bin/bash -c` with a standard `PATH`.

## ProcessResult

Every execution returns a `ProcessResult` with:

| Property | Type | Description |
|----------|------|-------------|
| `id` | `UUID` | Unique identifier |
| `exitCode` | `Int32` | Process exit code |
| `stdout` | `String` | Captured standard output |
| `stderr` | `String` | Captured standard error |
| `duration` | `TimeInterval` | Execution time in seconds |
| `startedAt` | `Date` | When execution began |
| `succeeded` | `Bool` | Whether exit code is `0` |

## Formatting Output

Combine stdout and stderr for display:

```swift
let output = ProcessExecutor.formatOutput(result)                // stdout + stderr
let stdoutOnly = ProcessExecutor.formatOutput(result, includeStderr: false)
```

## Error Handling

`ProcessExecutor` throws `ProcessExecutionError`:

```swift
do {
    let result = try ProcessExecutor.execute("/nonexistent/binary")
} catch let error as ProcessExecutionError {
    print(error.localizedDescription)
    // "Process execution failed: ..."
}
```
