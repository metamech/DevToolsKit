import SwiftUI

/// Built-in performance dashboard panel.
public struct PerformancePanel: DevToolPanel {
    public let id = "devtools.performance"
    public let title = "Performance"
    public let icon = "gauge"
    public let keyboardShortcut = DevToolsKeyboardShortcut(key: "m")
    public let preferredSize = CGSize(width: 700, height: 500)
    public let minimumSize = CGSize(width: 500, height: 400)

    private let provider: any MetricsProvider

    public init(provider: any MetricsProvider) {
        self.provider = provider
    }

    public func makeBody() -> AnyView {
        AnyView(PerformancePanelView(provider: provider))
    }
}
