import Foundation

/// Protocol for providing app-specific diagnostic data for export.
///
/// Register providers with `DevToolsManager.registerDiagnosticProvider(_:)`.
@MainActor
public protocol DiagnosticProvider {
    /// Section name used as the key in the exported JSON.
    var sectionName: String { get }

    /// Collect the diagnostic data for this section.
    func collect() async -> any Codable & Sendable
}
