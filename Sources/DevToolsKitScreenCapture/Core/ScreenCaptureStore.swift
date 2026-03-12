import Foundation
import Observation

#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// File-backed store for screen captures with thumbnails and filtering.
///
/// Captures are persisted as individual files: `{uuid}.json` (metadata),
/// `{uuid}.png` (full image), and `{uuid}.thumb.png` (thumbnail).
///
/// Since 0.5.0
@MainActor
@Observable
public final class ScreenCaptureStore: Sendable {
    /// All loaded entries, sorted by timestamp (newest first).
    public private(set) var entries: [ScreenCaptureEntry] = []

    /// Filter by capture mode (nil = all modes).
    public var filterMode: ScreenCaptureMode?

    /// Filter by date range (nil = no date filter).
    public var filterDateRange: ClosedRange<Date>?

    /// Entries matching current filter criteria.
    public var filteredEntries: [ScreenCaptureEntry] {
        entries.filter { entry in
            let matchesMode = filterMode == nil || entry.mode == filterMode
            let matchesDate = filterDateRange == nil || filterDateRange!.contains(entry.timestamp)
            return matchesMode && matchesDate
        }
    }

    /// Directory where capture files are stored.
    public let storageDirectory: URL

    /// Maximum number of captures to retain; nil for unlimited.
    public let maxCaptures: Int?

    /// Total bytes of all stored images.
    public var totalStorageBytes: Int { entries.reduce(0) { $0 + $1.imageDataSize } }

    /// - Parameters:
    ///   - storageDirectory: Directory for persisting capture files.
    ///   - maxCaptures: Maximum captures to retain; nil for unlimited.
    public init(storageDirectory: URL, maxCaptures: Int? = nil) {
        self.storageDirectory = storageDirectory
        self.maxCaptures = maxCaptures
    }

    // MARK: - CRUD

    /// Save a capture result, generating thumbnail. Returns the entry.
    ///
    /// - Parameter result: The capture result to save.
    /// - Returns: The persisted screen capture entry.
    @discardableResult
    public func save(_ result: ScreenCaptureResult) throws -> ScreenCaptureEntry {
        try ensureStorageDirectory()

        let entry = ScreenCaptureEntry(result: result)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(entry)

        let jsonURL = storageDirectory.appendingPathComponent("\(entry.id.uuidString).json")
        try jsonData.write(to: jsonURL, options: .atomic)

        let imageURL = storageDirectory.appendingPathComponent("\(entry.id.uuidString).png")
        try result.imageData.write(to: imageURL, options: .atomic)

        if let thumbData = generateThumbnail(from: result.imageData) {
            let thumbURL = storageDirectory.appendingPathComponent("\(entry.id.uuidString).thumb.png")
            try thumbData.write(to: thumbURL, options: .atomic)
        }

        entries.insert(entry, at: 0)
        trimIfNeeded()

        return entry
    }

    /// Delete a capture by ID from both store and disk.
    ///
    /// - Parameter id: The capture's UUID.
    public func delete(id: UUID) {
        entries.removeAll { $0.id == id }
        let fm = FileManager.default
        let jsonURL = storageDirectory.appendingPathComponent("\(id.uuidString).json")
        let imageURL = storageDirectory.appendingPathComponent("\(id.uuidString).png")
        let thumbURL = storageDirectory.appendingPathComponent("\(id.uuidString).thumb.png")
        try? fm.removeItem(at: jsonURL)
        try? fm.removeItem(at: imageURL)
        try? fm.removeItem(at: thumbURL)
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

        var loaded: [ScreenCaptureEntry] = []
        for file in jsonFiles {
            let data = try Data(contentsOf: file)
            let entry = try decoder.decode(ScreenCaptureEntry.self, from: data)
            loaded.append(entry)
        }

        entries = loaded.sorted { $0.timestamp > $1.timestamp }
        trimIfNeeded()
    }

    // MARK: - Image Access

    /// Read the full image data for a capture entry.
    ///
    /// - Parameter entry: The capture entry.
    /// - Returns: PNG image data, or nil if the file is missing.
    public func imageData(for entry: ScreenCaptureEntry) -> Data? {
        let imageURL = storageDirectory.appendingPathComponent("\(entry.id.uuidString).png")
        return try? Data(contentsOf: imageURL)
    }

    /// Read the thumbnail data for a capture entry.
    ///
    /// - Parameter entry: The capture entry.
    /// - Returns: PNG thumbnail data, or nil if the file is missing.
    public func thumbnailData(for entry: ScreenCaptureEntry) -> Data? {
        let thumbURL = storageDirectory.appendingPathComponent("\(entry.id.uuidString).thumb.png")
        return try? Data(contentsOf: thumbURL)
    }

    // MARK: - Private

    private func ensureStorageDirectory() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: storageDirectory.path) {
            try fm.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }
    }

    private func trimIfNeeded() {
        guard let max = maxCaptures, entries.count > max else { return }
        let toRemove = entries.suffix(from: max)
        let fm = FileManager.default
        for entry in toRemove {
            let jsonURL = storageDirectory.appendingPathComponent("\(entry.id.uuidString).json")
            let imageURL = storageDirectory.appendingPathComponent("\(entry.id.uuidString).png")
            let thumbURL = storageDirectory.appendingPathComponent("\(entry.id.uuidString).thumb.png")
            try? fm.removeItem(at: jsonURL)
            try? fm.removeItem(at: imageURL)
            try? fm.removeItem(at: thumbURL)
        }
        entries = Array(entries.prefix(max))
    }

    private func generateThumbnail(from imageData: Data, maxSize: CGFloat = 200) -> Data? {
        #if canImport(AppKit)
        guard let image = NSImage(data: imageData) else { return nil }
        let aspectRatio = image.size.width / image.size.height
        let thumbSize: NSSize
        if aspectRatio > 1 {
            thumbSize = NSSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            thumbSize = NSSize(width: maxSize * aspectRatio, height: maxSize)
        }
        let thumbImage = NSImage(size: thumbSize)
        thumbImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: thumbSize))
        thumbImage.unlockFocus()
        guard let tiffData = thumbImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData),
              let pngData = rep.representation(using: .png, properties: [:]) else { return nil }
        return pngData
        #elseif canImport(UIKit)
        guard let image = UIImage(data: imageData) else { return nil }
        let aspectRatio = image.size.width / image.size.height
        let thumbSize: CGSize
        if aspectRatio > 1 {
            thumbSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            thumbSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }
        let renderer = UIGraphicsImageRenderer(size: thumbSize)
        let thumbData = renderer.pngData { context in
            image.draw(in: CGRect(origin: .zero, size: thumbSize))
        }
        return thumbData
        #else
        return nil
        #endif
    }
}
