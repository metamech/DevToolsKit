# DevToolsKit Documentation

In-app developer tools for macOS SwiftUI apps.

## Modules

DevToolsKit is a multi-product Swift package. Import only what you need.

| Module | Description | Dependencies |
|--------|-------------|--------------|
| **[DevToolsKit](core/QUICK_START.md)** | Core panel system, window management, diagnostic export, built-in panels | None |
| **[DevToolsKitLogging](logging/GUIDE.md)** | swift-log integration with filterable log viewer panel | DevToolsKit, [swift-log](https://github.com/apple/swift-log) |
| **[DevToolsKitMetrics](metrics/GUIDE.md)** | swift-metrics integration with storage, query, and metrics inspector panel | DevToolsKit, [swift-metrics](https://github.com/apple/swift-metrics) |
| **[DevToolsKitLicensing](licensing/FEATURE_FLAGS.md)** | Feature flags, experimentation (cohorts/rollouts), license gating | DevToolsKit, [swift-metrics](https://github.com/apple/swift-metrics) |
| **[DevToolsKitProcess](process/GUIDE.md)** | Process execution with timeout, stdout/stderr capture | None |
| **[DevToolsKitSecurity](security/GUIDE.md)** | Permissions, sandbox validation, bookmarks, command policy | DevToolsKit |
| **[DevToolsKitGitHub](github/GUIDE.md)** | GitHub REST API client with caching, retry, rate limiting | DevToolsKit |
| **[DevToolsKitDiff](diff/GUIDE.md)** | Unified diff parsing, application, and validation | None |
| **[DevToolsKitCodeAnalysis](codeanalysis/GUIDE.md)** | Language-agnostic code analysis: security, performance, complexity, metrics, reports | DevToolsKit |
| **[DevToolsKitCodeAnalysisSwift](codeanalysis-swift/GUIDE.md)** | Swift-specific analysis rules | DevToolsKitCodeAnalysis |
| **[DevToolsKitMetricsStore](metrics-store/GUIDE.md)** | Persistent SwiftData metrics storage, enhanced queries, rollups, retention | DevToolsKitMetrics |

## Quick Links

### Getting Started
- [Quick Start](core/QUICK_START.md) — Add DevToolsKit to your app in 4 steps

### Core
- [Panel System](core/PANELS.md) — Built-in panels, custom panels, keyboard shortcuts
- [Window Modes](core/WINDOW_MODES.md) — Standalone, tabbed, and docked display
- [Diagnostic Export](core/EXPORT.md) — JSON diagnostic reports with custom sections
- [Menu Integration](core/MENU.md) — Auto-generated Developer menu
- [Core API Reference](core/API.md) — Full type signatures

### Logging (opt-in)
- [Logging Guide](logging/GUIDE.md) — swift-log integration and log viewer panel
- [Logging API Reference](logging/API.md)

### Metrics (opt-in)
- [Metrics Guide](metrics/GUIDE.md) — swift-metrics integration and metrics inspector panel
- [Metrics API Reference](metrics/API.md)

### Licensing & Feature Flags (opt-in)
- [Feature Flags Guide](licensing/FEATURE_FLAGS.md) — Define, gate, and override feature flags
- [Experimentation](licensing/EXPERIMENTATION.md) — Cohorts, percentage rollouts, targeting rules
- [License Backends](licensing/LICENSE_BACKENDS.md) — Pluggable license validation
- [Licensing API Reference](licensing/API.md)

### Process Execution (opt-in)
- [Process Guide](process/GUIDE.md) — Process execution with timeout and output capture
- [Process API Reference](process/API.md)

### Security (opt-in)
- [Security Guide](security/GUIDE.md) — Permissions, sandbox, bookmarks, command policy
- [Security API Reference](security/API.md)

### GitHub (opt-in)
- [GitHub Guide](github/GUIDE.md)
- [GitHub API Reference](github/API.md)

### Diff (opt-in)
- [Diff Guide](diff/GUIDE.md) — Unified diff parsing, application, and validation
- [Diff API Reference](diff/API.md)

### Code Analysis (opt-in)
- [Code Analysis Guide](codeanalysis/GUIDE.md) — Security, performance, complexity analysis and reporting
- [Code Analysis API Reference](codeanalysis/API.md)

### Swift Code Analysis (opt-in)
- [Swift Analysis Guide](codeanalysis-swift/GUIDE.md) — Swift-specific rules
- [Swift Analysis API Reference](codeanalysis-swift/API.md)

### Metrics Store (opt-in)
- [Metrics Store Guide](metrics-store/GUIDE.md) — Persistent storage, enhanced queries, rollups, retention
- [Metrics Store API Reference](metrics-store/API.md)

### Cross-Module
- [Testing Patterns](TESTING.md)
- [AI Coding Prompts](AI_PROMPTS.md)
- [Contributing](CONTRIBUTING.md)

## Version History

| Version | Highlights |
|---------|------------|
| 0.3.0 | DevToolsKitMetrics module (swift-metrics integration, metrics inspector panel) |
| 0.2.0 | DevToolsKitLicensing module (feature flags, experimentation, license gating) |
| 0.1.0 | Initial release — core panel system, logging, environment, data inspector, export |
