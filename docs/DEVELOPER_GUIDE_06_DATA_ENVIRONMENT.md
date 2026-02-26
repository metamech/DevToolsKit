[< Performance Panel](DEVELOPER_GUIDE_05_PERFORMANCE_PANEL.md) | [Index](DEVELOPER_GUIDE_00_OVERVIEW.md) | [Diagnostic Export >](DEVELOPER_GUIDE_07_DIAGNOSTIC_EXPORT.md)

# Developer Guide: Data Inspector & Environment Panel

## Data Inspector

A collapsible tree view for inspecting JSON-compatible or dictionary data.

### Setup

```swift
let config: [String: Any] = [
    "model": "llama-3",
    "parameters": ["temperature": 0.7, "maxTokens": 1024]
]

devTools.register(DataInspectorPanel(
    id: "myapp.config",
    title: "Config Inspector",
    dataTitle: "Agent Configuration",
    data: config,
    keyboardShortcut: DevToolsKeyboardShortcut(key: "i")
))
```

### Multiple Instances

`DataInspectorPanel` supports configurable IDs, so you can register multiple inspectors:

```swift
devTools.register(DataInspectorPanel(id: "myapp.request", title: "Request", data: requestData))
devTools.register(DataInspectorPanel(id: "myapp.response", title: "Response", data: responseData))
```

### Using DataInspectorView Directly

You can embed the view in your own panels:

```swift
DataInspectorView(title: "API Response", json: responseJSON)
DataInspectorView(title: "Settings", dictionary: settingsDict)
```

### UI Features

- Expand/Collapse All buttons
- Disclosure triangles for nested objects and arrays
- Summary badges: `{3}` for objects, `[5]` for arrays
- Values displayed in blue with text selection enabled
- Monospaced font throughout

## Environment Panel

Zero-configuration system info panel.

### Setup

```swift
devTools.register(EnvironmentPanel())
```

### Displayed Information

| Field | Source |
|-------|--------|
| macOS Version | `ProcessInfo.operatingSystemVersion` |
| Hardware Model | `uname()` machine field |
| Physical Memory | `ProcessInfo.physicalMemory` |
| Processor Count | `ProcessInfo.processorCount` |
| Active Processor Count | `ProcessInfo.activeProcessorCount` |
| Thermal State | `ProcessInfo.thermalState` |
| App Version | `CFBundleShortVersionString` |
| Build Number | `CFBundleVersion` |
| Bundle ID | `Bundle.main.bundleIdentifier` |
| Process Memory | `mach_task_basic_info` |
| System Uptime | `ProcessInfo.systemUptime` |
| Low Power Mode | `ProcessInfo.isLowPowerModeEnabled` |

### UI Features

- Manual refresh button
- Copy to clipboard button (plain text format)
- Monospaced two-column layout (key: value)

---

[< Performance Panel](DEVELOPER_GUIDE_05_PERFORMANCE_PANEL.md) | [Index](DEVELOPER_GUIDE_00_OVERVIEW.md) | [Diagnostic Export >](DEVELOPER_GUIDE_07_DIAGNOSTIC_EXPORT.md)
