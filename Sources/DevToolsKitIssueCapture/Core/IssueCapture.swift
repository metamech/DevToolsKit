import Foundation

/// A captured issue report comparing actual vs expected app state.
///
/// Each capture records the current state (auto-captured from a provider),
/// the expected state (entered by the user), optional notes, tags, and
/// a screenshot. Captures are persisted as JSON files.
///
/// Since 0.5.0
public struct IssueCapture: Codable, Sendable, Identifiable {
    /// Unique identifier for this capture.
    public let id: UUID

    /// When the capture was taken.
    public let timestamp: Date

    /// Identifier of the provider that supplied the captured state.
    public let providerID: String

    /// Display name of the provider at capture time.
    public let providerName: String

    /// Auto-captured current state from the provider.
    public let capturedState: [String: String]

    /// User-entered expected state values.
    public let expectedState: [String: String]

    /// Optional free-text notes.
    public let notes: String?

    /// User-assigned tags for categorization.
    public let tags: [String]

    /// Optional PNG screenshot data (base64-encoded in JSON).
    public let screenshotData: Data?

    /// - Parameters:
    ///   - id: Unique identifier; defaults to a new UUID.
    ///   - timestamp: When captured; defaults to now.
    ///   - providerID: The provider's identifier.
    ///   - providerName: The provider's display name.
    ///   - capturedState: Auto-captured state key-value pairs.
    ///   - expectedState: User-entered expected state key-value pairs.
    ///   - notes: Optional free-text notes.
    ///   - tags: Tags for categorization; defaults to empty.
    ///   - screenshotData: Optional PNG screenshot data.
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        providerID: String,
        providerName: String,
        capturedState: [String: String],
        expectedState: [String: String],
        notes: String? = nil,
        tags: [String] = [],
        screenshotData: Data? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.providerID = providerID
        self.providerName = providerName
        self.capturedState = capturedState
        self.expectedState = expectedState
        self.notes = notes
        self.tags = tags
        self.screenshotData = screenshotData
    }
}
