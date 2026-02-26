# Developer Guide: Testing

## Testing Code That Uses DevToolsKit

### Testing Panel Registration

```swift
@Test @MainActor func registersCustomPanel() {
    let manager = DevToolsManager(keyPrefix: "test")
    let panel = MyCustomPanel()
    manager.register(panel)

    #expect(manager.panels.count == 1)
    #expect(manager.panel(for: panel.id) != nil)
}
```

### Testing Display Modes

```swift
@Test @MainActor func setsDisplayMode() {
    let manager = DevToolsManager(keyPrefix: "test")
    manager.register(LogPanel(logStore: DevToolsLogStore()))

    manager.setDisplayMode(.docked, for: "devtools.log")
    #expect(manager.displayMode(for: "devtools.log") == .docked)
}
```

### Testing Log Store

```swift
@Test @MainActor func filtersLogEntries() {
    let store = DevToolsLogStore(maxEntries: 100)
    store.append(DevToolsLogEntry(level: .debug, source: "A", message: "debug msg"))
    store.append(DevToolsLogEntry(level: .error, source: "B", message: "error msg"))

    store.filterLevel = .error
    #expect(store.filteredEntries.count == 1)
    #expect(store.filteredEntries.first?.source == "B")
}
```

### Testing Diagnostic Providers

```swift
@Test @MainActor func collectsDiagnosticData() async {
    let provider = MyDiagnosticProvider()
    let data = await provider.collect()
    // Assert on the collected data structure
}
```

### Testing MetricsProvider

```swift
@Test @MainActor func collectsMetrics() async {
    let provider = MyMetricsProvider()
    let groups = await provider.currentMetrics()
    #expect(!groups.isEmpty)
    #expect(groups.first?.metrics.first?.value > 0)
}
```

## Key Prefix Isolation

Use unique `keyPrefix` values in tests to prevent UserDefaults pollution between test cases:

```swift
let manager = DevToolsManager(keyPrefix: "test-\(UUID().uuidString)")
```

## Mock Panels

Create minimal panel conformances for testing:

```swift
struct MockPanel: DevToolPanel {
    let id: String
    let title: String
    let icon = "square"
    func makeBody() -> AnyView { AnyView(EmptyView()) }
}
```

## Running Tests

```bash
swift test --package-path DevToolsKit
```
