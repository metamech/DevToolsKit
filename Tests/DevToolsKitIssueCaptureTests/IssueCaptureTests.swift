import Foundation
import Testing

@testable import DevToolsKitIssueCapture

@Suite("IssueCaptureField Tests")
struct IssueCaptureFieldTests {
    @Test("Text field exposes correct properties")
    func textField() {
        let field = IssueCaptureField.text(id: "notes", label: "Notes", placeholder: "Enter notes")
        #expect(field.id == "notes")
        #expect(field.label == "Notes")
    }

    @Test("QuickSelect field exposes correct properties")
    func quickSelectField() {
        let field = IssueCaptureField.quickSelect(
            id: "status", label: "Status", options: ["working", "idle", "error"]
        )
        #expect(field.id == "status")
        #expect(field.label == "Status")
    }

    @Test("MultiSelect field exposes correct properties")
    func multiSelectField() {
        let field = IssueCaptureField.multiSelect(
            id: "tags", label: "Tags", options: ["ui", "data", "network"]
        )
        #expect(field.id == "tags")
        #expect(field.label == "Tags")
    }
}

@Suite("IssueCapture Model Tests")
struct IssueCaptureModelTests {
    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let original = IssueCapture(
            providerID: "test.provider",
            providerName: "Test Provider",
            capturedState: ["status": "working"],
            expectedState: ["status": "idle"],
            notes: "State mismatch observed",
            tags: ["ui", "state"],
            screenshotData: Data([0x89, 0x50, 0x4E, 0x47])
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(IssueCapture.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.providerID == original.providerID)
        #expect(decoded.providerName == original.providerName)
        #expect(decoded.capturedState == original.capturedState)
        #expect(decoded.expectedState == original.expectedState)
        #expect(decoded.notes == original.notes)
        #expect(decoded.tags == original.tags)
        #expect(decoded.screenshotData == original.screenshotData)
    }

    @Test("Default values are correct")
    func defaults() {
        let capture = IssueCapture(
            providerID: "p",
            providerName: "P",
            capturedState: [:],
            expectedState: [:]
        )

        #expect(capture.notes == nil)
        #expect(capture.tags.isEmpty)
        #expect(capture.screenshotData == nil)
    }

    @Test("Hashable equality is by ID")
    func hashableEquality() {
        let id = UUID()
        let a = IssueCapture(
            id: id,
            providerID: "a",
            providerName: "A",
            capturedState: ["x": "1"],
            expectedState: ["x": "2"]
        )
        let b = IssueCapture(
            id: id,
            providerID: "b",
            providerName: "B",
            capturedState: ["y": "3"],
            expectedState: ["y": "4"]
        )
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }
}
