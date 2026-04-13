import DevToolsKit
import SwiftUI

/// Built-in feature flags panel that displays flag states and overrides.
///
/// Opens with shortcut Cmd+Opt+F. Register with a `FeatureFlagStore` instance:
///
/// ```swift
/// let store = FeatureFlagStore(overrideStore: UserDefaultsOverrideStore(keyPrefix: "myapp"))
/// manager.register(FeatureFlagsPanel(store: store))
/// ```
public struct FeatureFlagsPanel: DevToolPanel {
    public let id = "devtools.feature-flags"
    public let title = "Feature Flags"
    public let icon = "flag"
    public let keyboardShortcut = DevToolsKeyboardShortcut(key: "f")
    public let preferredSize = CGSize(width: 800, height: 600)
    public let minimumSize = CGSize(width: 600, height: 400)

    private let store: FeatureFlagStore

    public init(store: FeatureFlagStore) {
        self.store = store
    }

    public func makeBody() -> AnyView {
        AnyView(FeatureFlagsPanelView(store: store))
    }
}
