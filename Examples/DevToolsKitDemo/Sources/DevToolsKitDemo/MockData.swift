import DevToolsKit
import DevToolsKitCodeAnalysis
import DevToolsKitIssueCapture
import DevToolsKitLicensing
import DevToolsKitLogging
import DevToolsKitMetrics
import DevToolsKitSecurity
import Foundation

// MARK: - Mock License Backend

@MainActor
final class MockLicenseBackend: LicenseBackend, Sendable {
    var status: DevToolsLicenseStatus = .active
    var activeEntitlements: Set<String> = ["pro", "export"]

    func activate(with credential: LicenseCredential) async throws {
        status = .active
    }

    func validate() async throws {}

    func deactivate() async throws {
        status = .inactive
    }
}

// MARK: - Mock Metrics Provider (for PerformancePanel)

@MainActor
struct MockMetricsProvider: MetricsProvider, Sendable {
    func currentMetrics() async -> [MetricGroup] {
        [
            MetricGroup(name: "App", metrics: [
                Metric(name: "FPS", value: 59.8, unit: "fps", color: .green),
                Metric(name: "Memory", value: 124.5, unit: "MB", color: .blue),
                Metric(name: "CPU", value: 12.3, unit: "%", color: .orange),
            ]),
            MetricGroup(name: "Network", metrics: [
                Metric(name: "Latency", value: 42, unit: "ms", color: .purple),
                Metric(name: "Active Connections", value: 3, unit: "", color: .blue),
            ]),
        ]
    }
}

// MARK: - Mock Issue Capture Provider

@MainActor
struct MockIssueCaptureProvider: IssueCaptureProvider, Sendable {
    let id = "demo.appState"
    let displayName = "App State"

    func captureCurrentState() async -> [String: String] {
        [
            "status": "running",
            "activeTab": "home",
            "userLoggedIn": "true",
            "memoryUsage": "124 MB",
        ]
    }

    var expectedStateFields: [IssueCaptureField] {
        [
            .quickSelect(id: "status", label: "Expected Status", options: ["running", "idle", "error"]),
            .text(id: "notes", label: "Details", placeholder: "Describe the expected behavior"),
        ]
    }
}

// MARK: - Seed Functions

@MainActor
func seedLogStore(_ store: DevToolsLogStore) {
    let messages: [(DevToolsLogLevel, String, String)] = [
        (.info, "App", "Application launched successfully"),
        (.debug, "Network", "DNS resolved api.example.com in 12ms"),
        (.info, "Auth", "User session restored from keychain"),
        (.warning, "Database", "Query took 2.3s — consider adding an index"),
        (.info, "Network", "GET /api/v1/users → 200 OK (42ms)"),
        (.error, "Auth", "Token refresh failed: 401 Unauthorized"),
        (.debug, "App", "View controller loaded: HomeViewController"),
        (.trace, "Network", "TCP handshake completed in 8ms"),
        (.info, "Database", "Migration v12 → v13 completed"),
        (.warning, "App", "Low memory warning received"),
        (.info, "Network", "WebSocket connected to wss://live.example.com"),
        (.error, "Database", "Failed to decode User record: missing field 'email'"),
        (.debug, "Auth", "Checking biometric availability: Face ID"),
        (.info, "App", "Background refresh started"),
        (.warning, "Network", "Request retry #2 for POST /api/v1/events"),
    ]

    for (level, source, message) in messages {
        store.append(DevToolsLogEntry(
            level: level,
            source: source,
            message: message
        ))
    }
}

@MainActor
func seedMetricsStorage(_ storage: any MetricsStorage) {
    let now = Date()
    let entries: [(String, MetricType, Double, [(String, String)])] = [
        ("http.requests.total", .counter, 156, [("method", "GET")]),
        ("http.requests.total", .counter, 42, [("method", "POST")]),
        ("http.request.duration", .timer, 0.042, [("path", "/api/users")]),
        ("http.request.duration", .timer, 0.128, [("path", "/api/search")]),
        ("http.request.duration", .timer, 0.015, [("path", "/api/health")]),
        ("app.memory.bytes", .recorder, 130_457_600, []),
        ("app.cpu.percent", .recorder, 12.3, []),
        ("db.query.duration", .timer, 0.023, [("table", "users")]),
        ("db.query.duration", .timer, 2.31, [("table", "events")]),
        ("db.connections.active", .meter, 3, []),
        ("cache.hits", .counter, 1024, [("cache", "memory")]),
        ("cache.misses", .counter, 87, [("cache", "memory")]),
        ("ws.messages.received", .counter, 340, []),
        ("ws.messages.sent", .counter, 42, []),
        ("app.events.processed", .counter, 8942, []),
    ]

    for (index, (label, type, value, dims)) in entries.enumerated() {
        let entry = MetricEntry(
            timestamp: now.addingTimeInterval(Double(-entries.count + index) * 5),
            label: label,
            dimensions: dims,
            type: type,
            value: value
        )
        storage.record(entry)
    }
}

@MainActor
func seedPermissionAudit(_ store: PermissionAuditStore) {
    let entries: [(String, OperationCategory, PermissionLevel, PermissionSource, PermissionResponse, String)] = [
        ("Read file", .read, .allow, .appDefault, .allow, "/Users/demo/project/README.md"),
        ("Write file", .write, .ask, .projectOverride, .allow, "/Users/demo/project/config.json"),
        ("Execute process", .execute, .ask, .appDefault, .allowForSession, "git status"),
        ("Network request", .read, .allow, .appDefault, .allow, "GET https://api.example.com/health"),
        ("Delete file", .write, .ask, .sessionOverride, .deny, "/Users/demo/project/.env"),
    ]

    for (name, category, level, source, decision, args) in entries {
        store.record(PermissionAuditEntry(
            operationName: name,
            category: category,
            configuredLevel: level,
            source: source,
            decision: decision,
            argumentsSummary: args
        ))
    }
}

func sampleFeatureFlags() -> [FeatureFlagDefinition] {
    [
        FeatureFlagDefinition(
            id: "dark-mode-v2",
            name: "Dark Mode V2",
            description: "Enhanced dark mode with OLED-optimized colors",
            category: "UI",
            defaultEnabled: true,
            requiredTier: .free
        ),
        FeatureFlagDefinition(
            id: "ai-suggestions",
            name: "AI Suggestions",
            description: "AI-powered code suggestions in the editor",
            category: "Experimental",
            defaultEnabled: false,
            requiredTier: .premium
        ),
        FeatureFlagDefinition(
            id: "export-pdf",
            name: "PDF Export",
            description: "Export reports as PDF documents",
            category: "Export",
            defaultEnabled: true,
            requiredTier: .premium
        ),
        FeatureFlagDefinition(
            id: "debug-overlay",
            name: "Debug Overlay",
            description: "Show FPS counter and memory usage on screen",
            category: "Debug",
            defaultEnabled: false,
            requiredTier: .free
        ),
    ]
}

func sampleDataForInspector() -> [String: Any] {
    [
        "user": [
            "id": 12345,
            "name": "Jane Developer",
            "email": "jane@example.com",
            "roles": ["admin", "developer"],
            "preferences": [
                "theme": "dark",
                "language": "en",
                "notifications": true,
            ] as [String: Any],
        ] as [String: Any],
        "app": [
            "version": "2.1.0",
            "build": 428,
            "environment": "staging",
        ] as [String: Any],
        "session": [
            "token": "••••••••",
            "expiresAt": "2026-03-15T00:00:00Z",
            "refreshCount": 3,
        ] as [String: Any],
    ]
}

func sampleAnalysisResult() -> AnalysisResult {
    AnalysisResult(
        file: "Sources/App/NetworkManager.swift",
        language: .swift,
        issues: [
            Issue(
                severity: .error,
                category: .security,
                line: 42,
                message: "API key hardcoded in source",
                recommendation: "Move to environment variable or keychain"
            ),
            Issue(
                severity: .warning,
                category: .performance,
                line: 87,
                message: "Synchronous network call on main thread",
                recommendation: "Use async/await or dispatch to background queue"
            ),
            Issue(
                severity: .warning,
                category: .complexity,
                line: 123,
                column: 5,
                message: "Cyclomatic complexity of 15 exceeds threshold of 10",
                recommendation: "Extract helper methods to reduce branching"
            ),
            Issue(
                severity: .info,
                category: .style,
                line: 15,
                message: "Missing documentation on public method",
                recommendation: "Add /// doc comment describing the method's purpose"
            ),
            Issue(
                severity: .info,
                category: .duplication,
                line: 200,
                message: "Similar code block found at line 156",
                recommendation: "Extract shared logic into a reusable function"
            ),
        ],
        metrics: CodeMetrics(
            linesOfCode: 245,
            blankLines: 32,
            commentLines: 18,
            cyclomaticComplexity: 15,
            maintainabilityIndex: 62.5,
            duplicationPercentage: 8.3
        ),
        score: QualityScore(
            overall: 72.0,
            security: 45.0,
            performance: 78.0,
            maintainability: 65.0,
            style: 88.0
        ),
        duration: 0.34
    )
}
