import DevToolsKitLogging
import Logging
import Testing

/// Repro for #82 — `DevToolsLogHandler` shipped via the XCFramework binary
/// never appends to its `DevToolsLogStore`, while a structurally identical
/// `LogHandler` defined alongside it in the same `MultiplexLogHandler` does.
///
/// Pre-fix: `devToolsLogHandlerEntryAppearsAlongsideProbe` fails.
/// Post-fix: both assertions pass.

/// Local copy of `DevToolsLogHandler`'s dispatch pattern, defined in the
/// consumer (not the XCFramework). Used as the known-working control.
struct ProbeLogHandler: LogHandler, @unchecked Sendable {
    var logLevel: Logger.Level = .trace
    var metadata: Logger.Metadata = [:]

    let label: String
    let store: DevToolsLogStore

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let entry = DevToolsLogEntry(
            level: .info,
            source: label,
            message: "PROBE:\(message)",
            metadata: nil
        )
        Task { @MainActor in
            store.append(entry)
        }
    }
}

@MainActor
@Suite(.serialized)
struct LogHandlerXCFrameworkTests {
    /// Calls handler.log directly (skipping LoggingSystem.bootstrap) on both
    /// handlers in succession. The bug in #82 is that DevToolsLogHandler.log
    /// returns without store.append running, even though the call site is
    /// identical to ProbeLogHandler.
    @Test func devToolsLogHandlerEntryAppearsAlongsideProbe() async throws {
        let store = DevToolsLogStore()
        let label = "smoketest"

        var probe = ProbeLogHandler(label: label, store: store)
        var dtk = DevToolsLogHandler(label: label, store: store, osLogForwarding: false)
        probe.logLevel = .trace
        dtk.logLevel = .trace

        let multiplex = MultiplexLogHandler([probe, dtk])
        multiplex.log(
            level: .info,
            message: "hello",
            metadata: nil,
            source: label,
            file: #file,
            function: #function,
            line: #line
        )

        // Give the dispatch path time to run on the main queue.
        try await Task.sleep(for: .milliseconds(200))

        let messages = store.entries.map(\.message)
        #expect(messages.contains("PROBE:hello"))  // sanity: probe works
        #expect(messages.contains("hello"))  // #82: DevToolsLogHandler dispatch reaches the store
    }
}
