import DevToolsKit
import Logging
import Testing

@testable import DevToolsKitLogging

@Suite(.serialized)
@MainActor
struct LogHandlerTests {
    @Test func logHandlerAppendsToStore() async throws {
        let store = DevToolsLogStore()
        var handler = DevToolsLogHandler(label: "test.handler", store: store)
        handler.logLevel = .trace

        handler.log(
            level: .info,
            message: "Test message",
            metadata: nil,
            source: "test",
            file: #file,
            function: #function,
            line: #line
        )

        // Allow the Task to dispatch
        try await Task.sleep(for: .milliseconds(50))

        #expect(store.entries.count == 1)
        #expect(store.entries.first?.message == "Test message")
        #expect(store.entries.first?.source == "test.handler")
        #expect(store.entries.first?.level == .info)
    }

    @Test func logHandlerMapsLevels() async throws {
        let store = DevToolsLogStore()
        var handler = DevToolsLogHandler(label: "test", store: store)
        handler.logLevel = .trace

        let cases: [(Logging.Logger.Level, DevToolsLogLevel)] = [
            (.trace, .debug),
            (.debug, .debug),
            (.info, .info),
            (.notice, .info),
            (.warning, .warning),
            (.error, .error),
            (.critical, .error),
        ]

        for (logLevel, expected) in cases {
            handler.log(
                level: logLevel,
                message: "\(logLevel)",
                metadata: nil,
                source: "test",
                file: #file,
                function: #function,
                line: #line
            )
            try await Task.sleep(for: .milliseconds(20))
            #expect(store.entries.last?.level == expected, "Expected \(logLevel) to map to \(expected)")
        }
    }

    @Test func logHandlerIncludesMetadata() async throws {
        let store = DevToolsLogStore()
        var handler = DevToolsLogHandler(label: "test", store: store)
        handler.logLevel = .trace

        handler.log(
            level: .info,
            message: "With metadata",
            metadata: ["request-id": "abc123"],
            source: "test",
            file: #file,
            function: #function,
            line: #line
        )

        try await Task.sleep(for: .milliseconds(50))

        #expect(store.entries.first?.metadata?.contains("request-id") == true)
        #expect(store.entries.first?.metadata?.contains("abc123") == true)
    }
}
