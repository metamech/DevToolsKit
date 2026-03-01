import Testing
import Foundation
@testable import DevToolsKitSecurity

@Suite("PermissionAuditEntry")
struct PermissionAuditEntryTests {

    @Test func isCodable() throws {
        let entry = PermissionAuditEntry(
            operationName: "Write",
            category: .write,
            configuredLevel: .ask,
            source: .appDefault,
            decision: .allow,
            argumentsSummary: "file: test.txt"
        )

        let encoded = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(PermissionAuditEntry.self, from: encoded)

        #expect(decoded.operationName == "Write")
        #expect(decoded.category == .write)
        #expect(decoded.configuredLevel == .ask)
        #expect(decoded.source == .appDefault)
        #expect(decoded.argumentsSummary == "file: test.txt")
    }

    @Test func hasUniqueIdentifier() {
        let a = PermissionAuditEntry(
            operationName: "Read", category: .read, configuredLevel: .allow,
            source: .appDefault, decision: .allow, argumentsSummary: ""
        )
        let b = PermissionAuditEntry(
            operationName: "Read", category: .read, configuredLevel: .allow,
            source: .appDefault, decision: .allow, argumentsSummary: ""
        )
        #expect(a.id != b.id)
    }
}

@Suite("PermissionAuditStore")
@MainActor
struct PermissionAuditStoreTests {

    @Test func recordsEntries() {
        let store = PermissionAuditStore()
        let entry = PermissionAuditEntry(
            operationName: "Write", category: .write, configuredLevel: .ask,
            source: .appDefault, decision: .allow, argumentsSummary: "file: test.txt"
        )
        store.record(entry)
        #expect(store.entries.count == 1)
        #expect(store.entries.first?.operationName == "Write")
    }

    @Test func newestFirst() {
        let store = PermissionAuditStore()
        let entry1 = PermissionAuditEntry(
            operationName: "First", category: .read, configuredLevel: .allow,
            source: .appDefault, decision: .allow, argumentsSummary: ""
        )
        let entry2 = PermissionAuditEntry(
            operationName: "Second", category: .write, configuredLevel: .ask,
            source: .appDefault, decision: .deny, argumentsSummary: ""
        )
        store.record(entry1)
        store.record(entry2)
        #expect(store.entries.first?.operationName == "Second")
    }

    @Test func respectsMaxEntries() {
        let store = PermissionAuditStore(maxEntries: 3)
        for i in 0..<5 {
            let entry = PermissionAuditEntry(
                operationName: "Op\(i)", category: .read, configuredLevel: .allow,
                source: .appDefault, decision: .allow, argumentsSummary: ""
            )
            store.record(entry)
        }
        #expect(store.entries.count == 3)
    }

    @Test func clearRemovesAll() {
        let store = PermissionAuditStore()
        let entry = PermissionAuditEntry(
            operationName: "Test", category: .read, configuredLevel: .allow,
            source: .appDefault, decision: .allow, argumentsSummary: ""
        )
        store.record(entry)
        store.clear()
        #expect(store.entries.isEmpty)
    }
}
