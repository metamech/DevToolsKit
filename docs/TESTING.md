# Testing Patterns

[Index](INDEX.md)

## General Conventions

All tests use Swift Testing (`@Test`, `#expect`) with `@Suite(.serialized)` and `@MainActor`.

Isolate `UserDefaults` state with a unique key prefix:

```swift
let manager = DevToolsManager(keyPrefix: "test-\(UUID().uuidString)")
```

## Core: Panel Registration

```swift
@Test func registerPanel() {
    let manager = DevToolsManager(keyPrefix: "test-\(UUID().uuidString)")
    manager.register(MockPanel(id: "test.panel", title: "Test"))
    #expect(manager.panels.count == 1)
}

struct MockPanel: DevToolPanel {
    let id: String
    let title: String
    let icon = "wrench"
    let keyboardShortcut: DevToolsKeyboardShortcut? = nil
    let preferredSize = CGSize(width: 600, height: 400)
    let minimumSize = CGSize(width: 300, height: 200)
    func makeBody() -> AnyView { AnyView(Text("Mock")) }
}
```

## Core: Diagnostic Provider

```swift
struct TestProvider: DiagnosticProvider {
    let sectionName = "test"
    func collect() async -> any Codable & Sendable { ["key": "value"] }
}

@Test func diagnosticProvider() {
    let manager = DevToolsManager(keyPrefix: "test-\(UUID().uuidString)")
    manager.registerDiagnosticProvider(TestProvider())
    #expect(manager.diagnosticProviders.count == 1)
}
```

## Logging: Handler Dispatch

Handlers dispatch via `Task { @MainActor }` — wait for delivery:

```swift
@Test func logHandlerAppends() async throws {
    let store = DevToolsLogStore()
    let handler = DevToolsLogHandler(label: "test", store: store)
    handler.log(level: .info, message: "hello", metadata: nil, source: "test", ...)
    try await Task.sleep(for: .milliseconds(50))
    #expect(store.entries.count == 1)
}
```

## Metrics: Storage and Factory

```swift
@Test func counterRecords() async throws {
    let store = InMemoryMetricsStorage()
    let factory = DevToolsMetricsFactory(storage: store)
    factory.makeCounter(label: "test", dimensions: []).increment(by: 5)
    try await Task.sleep(for: .milliseconds(50))
    #expect(store.entryCount == 1)
}
```

## Licensing: Feature Flags

```swift
@Test func flagResolution() {
    let licensing = LicensingManager(keyPrefix: "test-\(UUID().uuidString)")
    licensing.registerFlag(FeatureFlagDefinition(
        id: "test.flag", name: "Test", description: "", category: "Test",
        defaultEnabled: true
    ))
    #expect(licensing.isEnabled("test.flag") == true)
}
```

## Screen Capture: Store CRUD

File-backed stores use a temp directory and clean up after each test:

```swift
@Test @MainActor func saveAndLoadAll() throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("Test-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = ScreenCaptureStore(storageDirectory: dir)
    let result = ScreenCaptureResult(
        imageData: Data(repeating: 0xAA, count: 64),
        size: CGSize(width: 800, height: 600),
        mode: .window, displayScale: 2.0
    )
    let entry = try store.save(result)
    #expect(store.entries.count == 1)

    let store2 = ScreenCaptureStore(storageDirectory: dir)
    try store2.loadAll()
    #expect(store2.entries.first?.id == entry.id)
}
```

## UI Flow Testing (SwiftUIFlowTesting)

[SwiftUIFlowTesting](https://github.com/metamech/SwiftUIFlowTesting) drives `@Observable` models through step sequences, renders the view at each step, and runs assertions after rendering. It is a test-only dependency.

Make the store conform to `FlowModel`, then build a step chain:

```swift
import SwiftUIFlowTesting
@testable import DevToolsKitScreenCapture

extension ScreenCaptureStore: FlowModel {}

@Suite @MainActor
struct ScreenCapturePanelFlowTests {
    @Test func filterByModeFlow() throws {
        let dir = makeTempDirectory()
        defer { cleanup(dir) }

        let store = ScreenCaptureStore(storageDirectory: dir)
        try store.save(makeResult(mode: .window))
        try store.save(makeResult(mode: .area))

        FlowTester(name: "filter", model: store) { store in
            ScreenCapturePanelView(store: store)
        }
        .step("all modes") { _ in
        } assert: { store in
            #expect(store.filteredEntries.count == 2)
        }
        .step("filter to window") { store in
            store.filterMode = .window
        } assert: { store in
            #expect(store.filteredEntries.count == 1)
        }
        .run(snapshotMode: .disabled)
    }
}
```

Key points:
- All tests must be `@MainActor` — `FlowTester` is MainActor-isolated
- Use `action:` and `assert:` labels to run assertions **after** rendering
- Use `.run(snapshotMode: .disabled)` to skip snapshot capture, or `.run()` for built-in snapshots
- See `Tests/DevToolsKitScreenCaptureFlowTests/` for full examples

## Running Tests

```bash
swift test                                            # All tests
swift test --filter DevToolsKitTests                  # Core only
swift test --filter DevToolsKitLoggingTests           # Logging only
swift test --filter DevToolsKitMetricsTests           # Metrics only
swift test --filter DevToolsKitLicensingTests         # Licensing only
swift test --filter DevToolsKitScreenCaptureTests     # Screen capture unit tests
swift test --filter DevToolsKitScreenCaptureFlowTests # Screen capture flow tests
```
