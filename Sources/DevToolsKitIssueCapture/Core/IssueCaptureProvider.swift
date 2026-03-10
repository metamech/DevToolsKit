/// Protocol for providing app-specific state to the issue capture system.
///
/// Conform to this protocol to expose your app's observable state for
/// capture. The provider reports the current state automatically and
/// defines the fields users fill in to describe the expected state.
///
/// ```swift
/// struct SessionStateProvider: IssueCaptureProvider {
///     let id = "session.state"
///     let displayName = "Session State"
///
///     func captureCurrentState() async -> [String: String] {
///         ["status": session.currentStatus.rawValue]
///     }
///
///     var expectedStateFields: [IssueCaptureField] {
///         [.quickSelect(id: "status", label: "Expected Status",
///                       options: ["working", "idle", "needsInput"])]
///     }
/// }
/// ```
///
/// Since 0.5.0
@MainActor
public protocol IssueCaptureProvider: Identifiable, Sendable where ID == String {
    /// Unique identifier for this provider.
    var id: String { get }

    /// Human-readable name shown in the capture UI.
    var displayName: String { get }

    /// Capture the current state of the system this provider monitors.
    ///
    /// - Returns: Key-value pairs describing the current state.
    func captureCurrentState() async -> [String: String]

    /// The fields presented to the user for describing expected state.
    var expectedStateFields: [IssueCaptureField] { get }
}
