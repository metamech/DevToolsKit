import DevToolsKit
import Foundation
import Testing

@testable import DevToolsKitLogging

@Suite(.serialized)
@MainActor
struct LogEntryFormattingTests {
    private func makeEntry(
        level: DevToolsLogLevel = .info,
        source: String = "test",
        message: String = "Hello",
        metadata: String? = nil,
        timestamp: Date = Date(timeIntervalSince1970: 1_710_244_245.123)
    ) -> DevToolsLogEntry {
        DevToolsLogEntry(
            level: level, source: source, message: message,
            metadata: metadata, timestamp: timestamp
        )
    }

    @Test func formatLine_basicEntry() {
        let entry = makeEntry()
        let line = LogEntryFormatter.formatLine(entry)

        #expect(line.contains("INF"))
        #expect(line.contains("[test]"))
        #expect(line.contains("Hello"))
        #expect(!line.contains("\n"))
    }

    @Test func formatLine_withMetadata() {
        let entry = makeEntry(metadata: "requestID=abc")
        let line = LogEntryFormatter.formatLine(entry)

        #expect(line.contains("Hello"))
        #expect(line.contains("\n"))
        #expect(line.contains("requestID=abc"))
    }

    @Test func formatLine_allLevels() {
        let levels: [(DevToolsLogLevel, String)] = [
            (.trace, "TRC"), (.debug, "DBG"), (.info, "INF"),
            (.warning, "WRN"), (.error, "ERR"),
        ]
        for (level, code) in levels {
            let line = LogEntryFormatter.formatLine(makeEntry(level: level))
            #expect(line.contains(code))
        }
    }

    @Test func formatText_multipleEntries() {
        let entries = [
            makeEntry(message: "First"),
            makeEntry(message: "Second"),
        ]
        let text = LogEntryFormatter.formatText(entries)

        #expect(text.contains("First"))
        #expect(text.contains("Second"))
        #expect(text.contains("\n"))
    }

    @Test func formatText_emptyArray() {
        let text = LogEntryFormatter.formatText([])
        #expect(text.isEmpty)
    }

    @Test func formatJSON_roundTrip() throws {
        let entry = makeEntry(source: "network", message: "Request sent", metadata: "url=/api")
        let json = try LogEntryFormatter.formatJSON([entry])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([DevToolsLogEntry].self, from: Data(json.utf8))

        #expect(decoded.count == 1)
        #expect(decoded[0].source == "network")
        #expect(decoded[0].message == "Request sent")
        #expect(decoded[0].metadata == "url=/api")
        #expect(decoded[0].level == .info)
    }

    @Test func formatJSON_emptyArray() throws {
        let json = try LogEntryFormatter.formatJSON([])
        #expect(json == "[\n\n]")
    }

    @Test func codable_roundTrip() throws {
        let entry = makeEntry(level: .warning, source: "db", message: "Slow query", metadata: "ms=500")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DevToolsLogEntry.self, from: data)

        #expect(decoded.id == entry.id)
        #expect(decoded.level == entry.level)
        #expect(decoded.source == entry.source)
        #expect(decoded.message == entry.message)
        #expect(decoded.metadata == entry.metadata)
    }
}
