import DevToolsKit
import Testing

@testable import DevToolsKitLogging

@Suite(.serialized)
@MainActor
struct LogStoreTests {
    @Test func appendEntry() {
        let store = DevToolsLogStore()

        let entry = DevToolsLogEntry(level: .info, source: "test", message: "Hello")
        store.append(entry)

        #expect(store.entries.count == 1)
        #expect(store.entries.first?.message == "Hello")
    }

    @Test func fifoCapacity() {
        let store = DevToolsLogStore(maxEntries: 10)

        for i in 0..<15 {
            store.append(DevToolsLogEntry(level: .info, source: "test", message: "Message \(i)"))
        }

        #expect(store.entries.count == 10)
        #expect(store.entries.first?.message == "Message 5")
        #expect(store.entries.last?.message == "Message 14")
    }

    @Test func filterByLevel() {
        let store = DevToolsLogStore()

        store.append(DevToolsLogEntry(level: .trace, source: "test", message: "Trace"))
        store.append(DevToolsLogEntry(level: .debug, source: "test", message: "Debug"))
        store.append(DevToolsLogEntry(level: .info, source: "test", message: "Info"))
        store.append(DevToolsLogEntry(level: .warning, source: "test", message: "Warning"))
        store.append(DevToolsLogEntry(level: .error, source: "test", message: "Error"))

        store.filterLevel = .warning
        #expect(store.filteredEntries.count == 2)
        #expect(store.filteredEntries.map(\.message) == ["Warning", "Error"])
    }

    @Test func filterByLevel_includesTrace() {
        let store = DevToolsLogStore()

        store.append(DevToolsLogEntry(level: .trace, source: "test", message: "Trace"))
        store.append(DevToolsLogEntry(level: .debug, source: "test", message: "Debug"))
        store.append(DevToolsLogEntry(level: .info, source: "test", message: "Info"))

        store.filterLevel = .trace
        #expect(store.filteredEntries.count == 3)
        #expect(store.filteredEntries.first?.message == "Trace")
    }

    @Test func traceIsLowestLevel() {
        #expect(DevToolsLogLevel.trace < .debug)
        #expect(DevToolsLogLevel.trace < .info)
        #expect(DevToolsLogLevel.trace < .warning)
        #expect(DevToolsLogLevel.trace < .error)
    }

    @Test func filterBySource() {
        let store = DevToolsLogStore()

        store.append(DevToolsLogEntry(level: .info, source: "logger", message: "From logger"))
        store.append(DevToolsLogEntry(level: .info, source: "network", message: "From network"))
        store.append(DevToolsLogEntry(level: .info, source: "logger", message: "Another logger"))

        store.filterSource = "logger"
        #expect(store.filteredEntries.count == 2)
    }

    @Test func filterBySearchText() {
        let store = DevToolsLogStore()

        store.append(DevToolsLogEntry(level: .info, source: "test", message: "User logged in"))
        store.append(DevToolsLogEntry(level: .info, source: "test", message: "Request failed"))
        store.append(DevToolsLogEntry(level: .info, source: "test", message: "User logged out"))

        store.searchText = "logged"
        #expect(store.filteredEntries.count == 2)
    }

    @Test func combinedFilters() {
        let store = DevToolsLogStore()

        store.append(DevToolsLogEntry(level: .debug, source: "network", message: "Debug network"))
        store.append(DevToolsLogEntry(level: .error, source: "network", message: "Error network"))
        store.append(DevToolsLogEntry(level: .error, source: "logger", message: "Error logger"))

        store.filterLevel = .error
        store.filterSource = "network"
        #expect(store.filteredEntries.count == 1)
        #expect(store.filteredEntries.first?.message == "Error network")
    }

    @Test func clear() {
        let store = DevToolsLogStore()

        store.append(DevToolsLogEntry(level: .info, source: "test", message: "Hello"))
        store.clear()

        #expect(store.entries.isEmpty)
    }

    @Test func knownSources() {
        let store = DevToolsLogStore()

        store.append(DevToolsLogEntry(level: .info, source: "b-network", message: "Net"))
        store.append(DevToolsLogEntry(level: .info, source: "a-logger", message: "Log"))
        store.append(DevToolsLogEntry(level: .info, source: "b-network", message: "Net2"))

        #expect(store.knownSources == ["a-logger", "b-network"])
    }

    @Test func recentEntries() {
        let store = DevToolsLogStore()

        for i in 0..<200 {
            store.append(DevToolsLogEntry(level: .info, source: "test", message: "Message \(i)"))
        }

        let recent = store.recentEntries(50)
        #expect(recent.count == 50)
        #expect(recent.first?.message == "Message 150")
    }
}
