import DevToolsKit
import SwiftUI

/// Built-in metrics inspector panel displaying swift-metrics data.
///
/// Opens with shortcut ⌘⌥I. Register with a shared ``MetricsManager`` instance:
///
/// ```swift
/// let metricsManager = MetricsManager()
/// manager.register(MetricsPanel(metricsManager: metricsManager))
/// ```
public struct MetricsPanel: DevToolPanel {
    public let id = "devtools.metrics"
    public let title = "Metrics"
    public let icon = "chart.bar"
    public let keyboardShortcut = DevToolsKeyboardShortcut(key: "i")
    public let preferredSize = CGSize(width: 800, height: 600)
    public let minimumSize = CGSize(width: 600, height: 400)

    private let metricsManager: MetricsManager

    /// - Parameter metricsManager: The shared metrics manager to display data from.
    public init(metricsManager: MetricsManager) {
        self.metricsManager = metricsManager
    }

    public func makeBody() -> AnyView {
        AnyView(MetricsPanelView(metricsManager: metricsManager))
    }
}
