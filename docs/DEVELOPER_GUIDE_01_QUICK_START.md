[< Overview](DEVELOPER_GUIDE_00_OVERVIEW.md) | [Index](DEVELOPER_GUIDE_00_OVERVIEW.md) | [Panel System >](DEVELOPER_GUIDE_02_PANEL_SYSTEM.md)

# Developer Guide: Quick Start

Add DevToolsKit to your macOS SwiftUI app in four steps.

## Step 1: Add the Dependency

In your `Package.swift` or Xcode project:

```swift
.package(url: "https://github.com/metamech/DevToolsKit.git", from: "1.0.0")
```

## Step 2: Create the Manager and Register Panels

```swift
import DevToolsKit
import Logging

@main struct MyApp: App {
    @State private var devTools = DevToolsManager(keyPrefix: "myapp")
    @State private var logStore = DevToolsLogStore()

    init() {
        // Register built-in panels
        devTools.register(LogPanel(logStore: logStore))
        devTools.register(EnvironmentPanel())

        // Optional: wire up swift-log
        LoggingSystem.bootstrap { label in
            DevToolsLogHandler(label: label, store: logStore)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .devToolsDock(devTools)      // Step 3
                .environment(devTools)
        }
        .commands {
            DevToolsCommands(manager: devTools) // Step 4
        }
    }
}
```

## Step 3: Attach the Dock

The `.devToolsDock(_:)` modifier wraps your content in a split view. When the dock is visible, panels appear below (or left/right of) your content. When hidden, the modifier is a no-op.

## Step 4: Add the Developer Menu

`DevToolsCommands` generates a "Developer" menu with:
- One entry per registered panel (with keyboard shortcuts)
- "Show All (Tabbed)" — ⌘⌥⇧D
- "Export Diagnostics..."
- Log level picker
- Developer mode toggle

## Verify

Run your app, open the Developer menu (or press ⌘⌥L), and you should see the Log Viewer panel.

---

[< Overview](DEVELOPER_GUIDE_00_OVERVIEW.md) | [Index](DEVELOPER_GUIDE_00_OVERVIEW.md) | [Panel System >](DEVELOPER_GUIDE_02_PANEL_SYSTEM.md)
