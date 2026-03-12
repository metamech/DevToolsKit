import DevToolsKit
import DevToolsKitCodeAnalysis
import DevToolsKitGitHub
import DevToolsKitIssueCapture
import DevToolsKitLicensing
import DevToolsKitLogging
import DevToolsKitMetrics
import DevToolsKitScreenCapture
import DevToolsKitSecurity
import Logging
import Metrics
import SwiftUI

/// Shared state created once before the App struct, avoiding escaping-closure issues.
@MainActor
private let sharedLogStore = DevToolsLogStore()

@MainActor
private let sharedMetricsManager = MetricsManager()

@MainActor
private let sharedAuditStore = PermissionAuditStore()

@MainActor
private let sharedScreenCaptureStore: ScreenCaptureStore = {
    let baseDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("DevToolsKitDemo", isDirectory: true)
    return ScreenCaptureStore(
        storageDirectory: baseDir.appendingPathComponent("screenshots")
    )
}()

@MainActor
private let sharedIssueCaptureStore: IssueCaptureStore = {
    let baseDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("DevToolsKitDemo", isDirectory: true)
    return IssueCaptureStore(
        storageDirectory: baseDir.appendingPathComponent("issues")
    )
}()

@MainActor
private let sharedLicensing: LicensingManager = {
    let backend = MockLicenseBackend()
    return LicensingManager(keyPrefix: "demo", backend: backend)
}()

@MainActor
private let bootstrapOnce: Void = {
    // swift-log → DevToolsLogStore
    let store = sharedLogStore
    LoggingSystem.bootstrap { label in
        DevToolsLogHandler(label: label, store: store)
    }

    // swift-metrics → InMemoryMetricsStorage
    MetricsSystem.bootstrap(
        DevToolsMetricsFactory(storage: sharedMetricsManager.storage)
    )

    // Seed mock data
    sharedLicensing.registerFlags(sampleFeatureFlags())
    seedLogStore(sharedLogStore)
    seedMetricsStorage(sharedMetricsManager.storage)
    seedPermissionAudit(sharedAuditStore)
}()

@main
struct DevToolsKitDemoApp: App {
    @State private var manager = DevToolsManager(keyPrefix: "demo")

    init() {
        // Trigger one-time bootstrap
        _ = bootstrapOnce

        // Register all panels
        manager.register(EnvironmentPanel())
        manager.register(PerformancePanel(provider: MockMetricsProvider()))
        manager.register(DataInspectorPanel(
            dataTitle: "Sample API Response",
            data: sampleDataForInspector(),
            keyboardShortcut: DevToolsKeyboardShortcut(key: "d")
        ))
        manager.register(LogPanel(logStore: sharedLogStore))
        manager.register(MetricsPanel(metricsManager: sharedMetricsManager))
        manager.register(FeatureFlagsPanel(licensing: sharedLicensing))
        manager.register(PermissionAuditPanel(store: sharedAuditStore))
        manager.register(GitHubStatusPanel(client: GitHubClient()))
        manager.register(CodeAnalysisPanel(result: sampleAnalysisResult()))
        manager.register(ScreenCapturePanel(store: sharedScreenCaptureStore))
        manager.register(IssueCapturePanel(
            store: sharedIssueCaptureStore,
            providers: [MockIssueCaptureProvider()]
        ))

        // Enable developer mode so the menu is active
        manager.isDeveloperMode = true
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                screenCaptureStore: sharedScreenCaptureStore
            )
            .devToolsDock(manager)
            .environment(manager)
        }
        .commands {
            DevToolsCommands(manager: manager)
        }
    }
}
