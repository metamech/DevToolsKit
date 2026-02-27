# Quick Start

[Index](../INDEX.md) | [Panels >](PANELS.md)

> **Module:** `DevToolsKit` (core, no external dependencies)

## 1. Add the Package Dependency

```swift
// Package.swift
.package(url: "https://github.com/metamech/DevToolsKit.git", from: "0.1.0")

// Target dependency
.product(name: "DevToolsKit", package: "DevToolsKit")
```

## 2. Create the Manager and Register Panels

```swift
import DevToolsKit
import SwiftUI

@main
struct MyApp: App {
    @State private var manager = DevToolsManager(keyPrefix: "myapp")

    init() {
        // Built-in panels (core — no extra imports needed)
        manager.register(EnvironmentPanel())

        // Optional: register additional modules' panels
        // See logging/, metrics/, licensing/ guides for details
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .devToolsDock(manager)     // Step 3
                .environment(manager)
        }
        .commands {
            DevToolsCommands(manager: manager)  // Step 4
        }
    }
}
```

## 3. Attach the Dock Modifier

The `.devToolsDock(_:)` modifier wraps your content in a split view. When a panel is docked, it appears alongside your app content. When no panel is docked, it has no visual effect.

## 4. Add the Developer Menu

`DevToolsCommands` generates a **Developer** menu containing:
- One entry per registered panel (with keyboard shortcuts)
- "Show All (Tabbed)" — ⌘⌥⇧D
- "Export Diagnostics..." — saves a JSON report
- Log level picker and developer mode toggle

## Verify

Run your app and press **⌘⌥E** to open the Environment panel. You should see system and app info in a two-column layout.

## Next Steps

- [Panel System](PANELS.md) — Create custom panels, learn keyboard shortcuts
- [Window Modes](WINDOW_MODES.md) — Standalone, tabbed, and docked display
- [Logging Guide](../logging/GUIDE.md) — Add swift-log integration
- [Metrics Guide](../metrics/GUIDE.md) — Add swift-metrics integration
- [Feature Flags Guide](../licensing/FEATURE_FLAGS.md) — Add feature flags and license gating
