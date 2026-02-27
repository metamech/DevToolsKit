import DevToolsKit
import SwiftUI

/// Built-in feature flags panel that displays flag states, license status, and experiments.
///
/// Opens with shortcut ⌘⌥F. Register with a `LicensingManager` instance:
///
/// ```swift
/// let licensing = LicensingManager(keyPrefix: "myapp", backend: myBackend)
/// manager.register(FeatureFlagsPanel(licensing: licensing))
/// ```
public struct FeatureFlagsPanel: DevToolPanel {
    public let id = "devtools.feature-flags"
    public let title = "Feature Flags"
    public let icon = "flag"
    public let keyboardShortcut = DevToolsKeyboardShortcut(key: "f")
    public let preferredSize = CGSize(width: 800, height: 600)
    public let minimumSize = CGSize(width: 600, height: 400)

    private let licensing: LicensingManager

    /// - Parameter licensing: The licensing manager to display and control.
    public init(licensing: LicensingManager) {
        self.licensing = licensing
    }

    public func makeBody() -> AnyView {
        AnyView(FeatureFlagsPanelView(licensing: licensing))
    }
}
