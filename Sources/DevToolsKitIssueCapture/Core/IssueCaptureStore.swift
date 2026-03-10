import Foundation
import Observation

/// File-backed store for issue captures with filtering and analysis.
///
/// Captures are persisted as individual JSON files in a storage directory.
/// The store provides filtering by provider, tag, date range, and search text,
/// plus analysis helpers for identifying patterns.
///
/// Since 0.5.0
@MainActor
@Observable
public final class IssueCaptureStore: Sendable {
    /// All loaded captures, sorted by timestamp (newest first).
    public private(set) var captures: [IssueCapture] = []

    /// Filter by provider ID (nil = all providers).
    public var filterProviderID: String?

    /// Filter by tag (nil = all tags).
    public var filterTag: String?

    /// Search text filter applied to notes and state values.
    public var searchText: String = ""

    /// Filter by date range (nil = no date filter).
    public var filterDateRange: ClosedRange<Date>?

    /// Maximum number of captures to retain; nil for unlimited.
    public let maxCaptures: Int?

    /// Directory where capture JSON files are stored.
    public let storageDirectory: URL

    /// Captures matching current filter criteria.
    public var filteredCaptures: [IssueCapture] {
        captures.filter { capture in
            let matchesProvider = filterProviderID == nil || capture.providerID == filterProviderID
            let matchesTag = filterTag == nil || capture.tags.contains(filterTag!)
            let matchesSearch = searchText.isEmpty || matchesSearchText(capture)
            let matchesDate = filterDateRange == nil || filterDateRange!.contains(capture.timestamp)
            return matchesProvider && matchesTag && matchesSearch && matchesDate
        }
    }

    /// All unique provider IDs across all captures.
    public var knownProviderIDs: [String] {
        Array(Set(captures.map(\.providerID))).sorted()
    }

    /// All unique tags across all captures.
    public var knownTags: [String] {
        Array(Set(captures.flatMap(\.tags))).sorted()
    }

    /// Captures grouped by provider ID.
    public var capturesByProvider: [String: [IssueCapture]] {
        Dictionary(grouping: captures, by: \.providerID)
    }

    /// - Parameters:
    ///   - storageDirectory: Directory for persisting capture JSON files.
    ///   - maxCaptures: Maximum captures to retain; nil for unlimited.
    public init(storageDirectory: URL, maxCaptures: Int? = nil) {
        self.storageDirectory = storageDirectory
        self.maxCaptures = maxCaptures
    }

    // MARK: - CRUD

    /// Save a new capture to the store and disk.
    ///
    /// - Parameter capture: The capture to save.
    public func save(_ capture: IssueCapture) throws {
        try ensureStorageDirectory()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(capture)

        let fileURL = storageDirectory.appendingPathComponent("\(capture.id.uuidString).json")
        try data.write(to: fileURL, options: .atomic)

        captures.insert(capture, at: 0)
        trimIfNeeded()
    }

    /// Delete a capture by ID from both store and disk.
    ///
    /// - Parameter id: The capture's UUID.
    public func delete(id: UUID) {
        captures.removeAll { $0.id == id }
        let fileURL = storageDirectory.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Delete multiple captures by ID.
    ///
    /// - Parameter ids: The UUIDs to delete.
    public func delete(ids: Set<UUID>) {
        for id in ids {
            delete(id: id)
        }
    }

    /// Load all captures from the storage directory.
    public func loadAll() throws {
        try ensureStorageDirectory()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil)
        let jsonFiles = contents.filter { $0.pathExtension == "json" }

        var loaded: [IssueCapture] = []
        for file in jsonFiles {
            let data = try Data(contentsOf: file)
            let capture = try decoder.decode(IssueCapture.self, from: data)
            loaded.append(capture)
        }

        captures = loaded.sorted { $0.timestamp > $1.timestamp }
        trimIfNeeded()
    }

    // MARK: - Analysis

    /// Find the most common expected values for a given field ID.
    ///
    /// - Parameter fieldID: The field identifier to analyze.
    /// - Returns: Value-count pairs sorted by frequency (most common first).
    public func commonExpectedValues(fieldID: String) -> [(value: String, count: Int)] {
        var counts: [String: Int] = [:]
        for capture in captures {
            if let value = capture.expectedState[fieldID] {
                counts[value, default: 0] += 1
            }
        }
        return counts.map { (value: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    /// Number of captures per calendar day for the filtered set.
    public var captureFrequency: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        var dayCounts: [Date: Int] = [:]
        for capture in filteredCaptures {
            let day = calendar.startOfDay(for: capture.timestamp)
            dayCounts[day, default: 0] += 1
        }
        return dayCounts.map { (date: $0.key, count: $0.value) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Export

    /// Export filtered captures as JSON data (without screenshot data for compactness).
    ///
    /// - Returns: JSON-encoded array of filtered captures.
    public func exportFiltered() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // Strip screenshot data for export compactness
        let stripped = filteredCaptures.map { capture in
            IssueCapture(
                id: capture.id,
                timestamp: capture.timestamp,
                providerID: capture.providerID,
                providerName: capture.providerName,
                capturedState: capture.capturedState,
                expectedState: capture.expectedState,
                notes: capture.notes,
                tags: capture.tags,
                screenshotData: nil
            )
        }

        return try encoder.encode(stripped)
    }

    // MARK: - Private

    private func ensureStorageDirectory() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: storageDirectory.path) {
            try fm.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }
    }

    private func trimIfNeeded() {
        guard let max = maxCaptures, captures.count > max else { return }
        let toRemove = captures.suffix(from: max)
        for capture in toRemove {
            let fileURL = storageDirectory.appendingPathComponent("\(capture.id.uuidString).json")
            try? FileManager.default.removeItem(at: fileURL)
        }
        captures = Array(captures.prefix(max))
    }

    private func matchesSearchText(_ capture: IssueCapture) -> Bool {
        if let notes = capture.notes,
           notes.localizedCaseInsensitiveContains(searchText) {
            return true
        }
        for (_, value) in capture.capturedState {
            if value.localizedCaseInsensitiveContains(searchText) { return true }
        }
        for (_, value) in capture.expectedState {
            if value.localizedCaseInsensitiveContains(searchText) { return true }
        }
        return false
    }
}
