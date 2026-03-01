import DevToolsKit
import SwiftUI

/// Built-in code analysis panel that displays quality scores and detected issues.
///
/// Shows the overall quality score, per-category breakdowns, and a filterable
/// list of issues grouped by severity and category.
///
/// ```swift
/// let analysisResult = try await analyzer.analyze(file)
/// manager.register(CodeAnalysisPanel(result: analysisResult))
/// ```
///
/// > Since: 0.4.0
public struct CodeAnalysisPanel: DevToolPanel {
    /// Panel identifier.
    public let id = "devtools.analysis"
    /// Display title.
    public let title = "Code Analysis"
    /// SF Symbol icon name.
    public let icon = "magnifyingglass.circle"
    /// Keyboard shortcut (Command+Option+A).
    public let keyboardShortcut = DevToolsKeyboardShortcut(key: "a")
    /// Preferred window size.
    public let preferredSize = CGSize(width: 800, height: 600)
    /// Minimum window size.
    public let minimumSize = CGSize(width: 600, height: 400)

    private let result: AnalysisResult?

    /// Create a code analysis panel with an optional initial result.
    /// - Parameter result: The analysis result to display. Pass nil for an empty panel.
    public init(result: AnalysisResult? = nil) {
        self.result = result
    }

    /// Create the panel view.
    public func makeBody() -> AnyView {
        AnyView(CodeAnalysisPanelView(result: result))
    }
}
