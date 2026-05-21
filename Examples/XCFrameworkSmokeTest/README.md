# XCFrameworkSmokeTest

A standalone SPM package that links DevToolsKit's prebuilt **release XCFrameworks**
(rather than the SPM source) and exercises behavior that only manifests in the
compiled binary. The default `swift test` suite cannot catch these issues because
it builds from source in debug.

## Why

Issue [#82](https://github.com/metamech/DevToolsKit/issues/82) — `DevToolsLogHandler`
entries never reached `DevToolsLogStore` when DevToolsKit was consumed as the
v0.15.0 XCFramework, despite a structurally identical `LogHandler` defined in the
consumer app working in the same `MultiplexLogHandler`. The bug was invisible to
`swift test`.

This package reproduces the failure in-repo and acts as a regression guard for
similar XCFramework-only bugs.

## Usage

Build the XCFrameworks from the local checkout (uses current working-tree source,
not a remote tag):

```bash
swift Scripts/build-xcframeworks.swift --product DevToolsKit --force
swift Scripts/build-xcframeworks.swift --product DevToolsKitLogging --force
```

Run the smoke test in release configuration:

```bash
swift test --package-path Examples/XCFrameworkSmokeTest -c release
```

The release flag is required — debug builds compile differently and do not
reproduce #82.

## Not part of `swift test`

This package is intentionally separate from the root `Package.swift`. It is not
run by CI or by the default `swift test` because it depends on prebuilt artifacts.
Run it manually after touching dispatch-sensitive code in any module that ships
as an XCFramework.
