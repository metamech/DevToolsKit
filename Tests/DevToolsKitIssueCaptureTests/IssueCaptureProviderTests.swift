import Foundation
import Testing

@testable import DevToolsKitIssueCapture

/// Mock provider for testing the IssueCaptureProvider protocol.
struct MockProvider: IssueCaptureProvider {
    let id: String
    let displayName: String
    let stateToReturn: [String: String]
    let fields: [IssueCaptureField]

    init(
        id: String = "mock",
        displayName: String = "Mock Provider",
        state: [String: String] = ["status": "active"],
        fields: [IssueCaptureField] = [
            .quickSelect(id: "status", label: "Expected Status", options: ["active", "idle", "error"]),
        ]
    ) {
        self.id = id
        self.displayName = displayName
        self.stateToReturn = state
        self.fields = fields
    }

    func captureCurrentState() async -> [String: String] {
        stateToReturn
    }

    var expectedStateFields: [IssueCaptureField] {
        fields
    }
}

@Suite("IssueCaptureProvider Tests")
struct IssueCaptureProviderTests {
    @Test("Mock provider returns configured state")
    @MainActor
    func captureState() async {
        let provider = MockProvider(state: ["status": "working", "count": "42"])
        let state = await provider.captureCurrentState()

        #expect(state["status"] == "working")
        #expect(state["count"] == "42")
        #expect(state.count == 2)
    }

    @Test("Provider exposes expected state fields")
    @MainActor
    func expectedFields() {
        let provider = MockProvider(fields: [
            .text(id: "notes", label: "Notes", placeholder: "..."),
            .quickSelect(id: "status", label: "Status", options: ["a", "b"]),
            .multiSelect(id: "tags", label: "Tags", options: ["x", "y", "z"]),
        ])

        #expect(provider.expectedStateFields.count == 3)
        #expect(provider.expectedStateFields[0].id == "notes")
        #expect(provider.expectedStateFields[1].id == "status")
        #expect(provider.expectedStateFields[2].id == "tags")
    }

    @Test("Provider conforms to Identifiable")
    @MainActor
    func identifiable() {
        let provider = MockProvider(id: "my.provider")
        #expect(provider.id == "my.provider")
    }

    @Test("Full capture workflow with mock provider")
    @MainActor
    func fullWorkflow() async throws {
        let provider = MockProvider(
            id: "session",
            displayName: "Session",
            state: ["status": "working"]
        )

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProviderTest-\(UUID().uuidString)")
        let store = IssueCaptureStore(storageDirectory: dir)
        defer { try? FileManager.default.removeItem(at: dir) }

        let currentState = await provider.captureCurrentState()
        let capture = IssueCapture(
            providerID: provider.id,
            providerName: provider.displayName,
            capturedState: currentState,
            expectedState: ["status": "idle"],
            notes: "State doesn't match"
        )

        try store.save(capture)
        #expect(store.captures.count == 1)
        #expect(store.captures[0].capturedState["status"] == "working")
        #expect(store.captures[0].expectedState["status"] == "idle")
    }
}
