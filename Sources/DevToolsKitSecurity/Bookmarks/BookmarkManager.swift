import Foundation

/// Manages security-scoped bookmarks for persistent file access in sandboxed apps.
///
/// Since 0.4.0
public struct BookmarkManager: Sendable {

    /// Errors related to bookmark operations.
    public enum BookmarkError: Error, LocalizedError, Sendable {
        /// Failed to create a security-scoped bookmark.
        case bookmarkCreationFailed
        /// Failed to resolve a security-scoped bookmark.
        case bookmarkResolutionFailed
        /// Bookmark is stale and needs to be recreated.
        case bookmarkStale

        public var errorDescription: String? {
            switch self {
            case .bookmarkCreationFailed:
                return "Failed to create security-scoped bookmark"
            case .bookmarkResolutionFailed:
                return "Failed to resolve security-scoped bookmark"
            case .bookmarkStale:
                return "Bookmark is stale and needs to be recreated"
            }
        }
    }

    /// Creates a new bookmark manager.
    public init() {}

    /// Create a security-scoped bookmark for a URL.
    /// - Parameter url: The file URL to bookmark.
    /// - Returns: Bookmark data that can be persisted.
    /// - Throws: ``BookmarkError/bookmarkCreationFailed`` if bookmark creation fails.
    public func createBookmark(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw BookmarkError.bookmarkCreationFailed
        }
    }

    /// Resolve a security-scoped bookmark to access the URL.
    /// - Parameter bookmarkData: The persisted bookmark data.
    /// - Returns: Resolved URL and a stop-accessing closure.
    /// - Throws: ``BookmarkError`` if resolution fails or bookmark is stale.
    public func resolveBookmark(
        _ bookmarkData: Data
    ) throws -> (url: URL, stopAccessing: @Sendable () -> Void) {
        var isStale = false

        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                throw BookmarkError.bookmarkStale
            }

            guard url.startAccessingSecurityScopedResource() else {
                throw BookmarkError.bookmarkResolutionFailed
            }

            return (url, { url.stopAccessingSecurityScopedResource() })
        } catch {
            if error is BookmarkError {
                throw error
            }
            throw BookmarkError.bookmarkResolutionFailed
        }
    }
}
