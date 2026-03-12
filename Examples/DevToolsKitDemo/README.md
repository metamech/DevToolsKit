# DevToolsKitDemo

Interactive demo app for DevToolsKit. Registers all 11 panels with mock data for manual testing and exploration.

## Requirements

- macOS 26+
- Xcode 26+ / Swift 6

## Run

From the repository root:

```bash
make demo
```

Or directly:

```bash
cd Examples/DevToolsKitDemo && swift run
```

## What's Included

All panels are registered with mock data and accessible via the Developer menu:

| Panel | Shortcut | Mock Data |
|-------|----------|-----------|
| Environment | ⌘⌥E | Live system info |
| Performance | ⌘⌥M | CPU, memory, disk metrics |
| Data Inspector | ⌘⌥D | Sample API response |
| Log Viewer | ⌘⌥L | Seeded log entries at all levels |
| Metrics Inspector | ⌘⌥I | Seeded counters, timers, gauges |
| Feature Flags | ⌘⌥F | 4 sample flags with categories |
| Permissions | ⌘⌥P | Seeded audit entries |
| GitHub Status | ⌘⌥G | Unconfigured client (placeholder) |
| Code Analysis | ⌘⌥A | Sample analysis result |
| Screen Capture | ⌘⌥H | Persistent file-backed store |
| Issue Capture | ⌘⌥R | Mock provider |

The content view provides action buttons to generate additional log entries, record metrics, and trigger screen captures at runtime.

## Storage

Capture data (screenshots, issues) is stored in the system temp directory under `DevToolsKitDemo/` and is not persisted across reboots.
