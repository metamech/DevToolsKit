import SwiftUI

/// Built-in performance dashboard panel that displays metrics from a ``MetricsProvider``.
///
/// Opens with shortcut ⌘⌥M. Supply your own provider to feed app-specific metrics:
///
/// ```swift
/// manager.register(PerformancePanel(provider: MyMetricsProvider()))
/// ```
public struct PerformancePanel: DevToolPanel {
    public let id = "devtools.performance"
    public let title = "Performance"
    public let icon = "gauge"
    public let keyboardShortcut = DevToolsKeyboardShortcut(key: "m")
    public let preferredSize = CGSize(width: 700, height: 500)
    public let minimumSize = CGSize(width: 500, height: 400)

    private let provider: any MetricsProvider

    /// - Parameter provider: The metrics provider that supplies performance data.
    public init(provider: any MetricsProvider) {
        self.provider = provider
    }

    public func makeBody() -> AnyView {
        AnyView(PerformancePanelView(provider: provider))
    }
}
