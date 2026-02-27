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

## Running Tests

```bash
swift test                                    # All tests
swift test --filter DevToolsKitTests          # Core only
swift test --filter DevToolsKitLoggingTests   # Logging only
swift test --filter DevToolsKitMetricsTests   # Metrics only
swift test --filter DevToolsKitLicensingTests # Licensing only
```
