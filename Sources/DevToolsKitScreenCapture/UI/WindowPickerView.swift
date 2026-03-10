#if canImport(AppKit)
import AppKit
import SwiftUI

/// macOS window picker for selecting which window to capture.
///
/// Displays a list of the application's visible windows.
///
/// Since 0.5.0
@MainActor
public struct WindowPickerView: View {
    @State private var windows: [(id: Int, title: String)] = []
    private let onSelect: (NSWindow) -> Void

    /// - Parameter onSelect: Called when the user picks a window.
    public init(onSelect: @escaping (NSWindow) -> Void) {
        self.onSelect = onSelect
    }

    public var body: some View {
        List(windows, id: \.id) { entry in
            Button {
                if let window = NSApplication.shared.windows.first(where: { $0.windowNumber == entry.id }) {
                    onSelect(window)
                }
            } label: {
                Label(entry.title.isEmpty ? "Untitled Window" : entry.title, systemImage: "macwindow")
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .onAppear {
            refreshWindows()
        }
    }

    private func refreshWindows() {
        windows = NSApplication.shared.windows
            .filter { $0.isVisible && !$0.title.isEmpty }
            .map { (id: $0.windowNumber, title: $0.title) }
    }
}
#endif
