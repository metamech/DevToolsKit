import Foundation

/// Utility for common file system operations.
///
/// Provides consistent path resolution, sandbox checking, and backup creation.
///
/// Since 0.4.0
public struct FileSystemUtility: Sendable {

    // MARK: - Path Resolution

    /// Resolves a path (relative or absolute) to an absolute URL.
    /// - Parameters:
    ///   - path: The path to resolve (can be relative or absolute).
    ///   - workingDirectory: The working directory to resolve relative paths against.
    /// - Returns: An absolute URL.
    public static func resolveURL(from path: String, workingDirectory: URL) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        } else {
            return workingDirectory.appendingPathComponent(path)
        }
    }

    /// Standardizes and resolves symlinks in a URL path.
    ///
    /// Ensures consistent path comparison, especially for `/var` vs `/private/var` on macOS.
    /// - Parameter url: The URL to standardize.
    /// - Returns: A standardized URL with symlinks resolved.
    public static func standardizeURL(_ url: URL) -> URL {
        url.standardized.resolvingSymlinksInPath()
    }

    /// Standardizes and resolves symlinks in a path string.
    /// - Parameter url: The URL to standardize.
    /// - Returns: The standardized path string.
    public static func standardizePath(_ url: URL) -> String {
        standardizeURL(url).path
    }

    // MARK: - Sandbox Validation

    /// Checks if a URL is within the allowed paths.
    ///
    /// Uses symlink resolution to handle `/var` vs `/private/var` correctly.
    /// - Parameters:
    ///   - url: The URL to check.
    ///   - allowedPaths: Set of allowed directory URLs.
    /// - Returns: `true` if the URL is within allowed paths.
    public static func isAllowed(_ url: URL, in allowedPaths: Set<URL>) -> Bool {
        let normalizedPath = standardizePath(url)
        return allowedPaths.contains { allowedPath in
            normalizedPath.hasPrefix(standardizePath(allowedPath))
        }
    }

    /// Validates that a path is within allowed directories.
    /// - Parameters:
    ///   - path: The path string being validated.
    ///   - url: The resolved URL to check.
    ///   - allowedPaths: Set of allowed directory URLs.
    /// - Throws: ``SandboxError/accessDenied(path:)`` if the path is outside allowed directories.
    public static func validateSandbox(
        path: String,
        url: URL,
        allowedPaths: Set<URL>
    ) throws {
        guard isAllowed(url, in: allowedPaths) else {
            throw SandboxError.accessDenied(path: path)
        }
    }

    /// Standardizes a set of allowed paths for efficient comparison.
    ///
    /// Call this once and reuse the result for multiple file checks.
    /// - Parameter allowedPaths: Set of allowed directory URLs.
    /// - Returns: Array of standardized path strings.
    public static func standardizeAllowedPaths(_ allowedPaths: Set<URL>) -> [String] {
        allowedPaths.map { standardizePath($0) }
    }

    /// Fast sandbox check using pre-standardized allowed paths.
    ///
    /// Use this when checking many files against the same allowed paths.
    /// - Parameters:
    ///   - url: The URL to check.
    ///   - standardizedAllowedPaths: Pre-standardized allowed paths.
    /// - Returns: `true` if allowed.
    public static func isAllowed(_ url: URL, in standardizedAllowedPaths: [String]) -> Bool {
        let normalizedPath = standardizePath(url)
        return standardizedAllowedPaths.contains { allowedPath in
            normalizedPath.hasPrefix(allowedPath)
        }
    }

    // MARK: - Relative Path Computation

    /// Computes a relative path from a base directory to a file.
    ///
    /// Handles symlink resolution to work correctly with `/var` vs `/private/var`.
    /// - Parameters:
    ///   - fileURL: The file URL.
    ///   - baseURL: The base directory URL.
    /// - Returns: Relative path string, or the filename if paths don't share a common base.
    public static func relativePath(from fileURL: URL, to baseURL: URL) -> String {
        let resolvedFilePath = standardizePath(fileURL)
        let resolvedBasePath = standardizePath(baseURL)

        if resolvedFilePath.hasPrefix(resolvedBasePath) {
            let relativePath = String(resolvedFilePath.dropFirst(resolvedBasePath.count))
            if relativePath.hasPrefix("/") {
                return String(relativePath.dropFirst())
            }
            return relativePath.isEmpty ? fileURL.lastPathComponent : relativePath
        }

        return fileURL.lastPathComponent
    }

    // MARK: - Backup Creation

    /// Creates a simple backup of a file by copying it with a `.backup` extension.
    /// - Parameter fileURL: The file to back up.
    /// - Returns: The backup URL.
    /// - Throws: FileManager errors if backup creation fails.
    @discardableResult
    public static func createSimpleBackup(of fileURL: URL) throws -> URL {
        let backupURL = fileURL.appendingPathExtension("backup")

        if FileManager.default.fileExists(atPath: backupURL.path) {
            try FileManager.default.removeItem(at: backupURL)
        }

        try FileManager.default.copyItem(at: fileURL, to: backupURL)
        return backupURL
    }

    /// Creates an archived backup of a file in the temporary directory.
    ///
    /// The backup is stored in `/tmp/devtoolskit-backups` with a timestamp.
    /// - Parameter fileURL: The file to back up.
    /// - Returns: The backup URL.
    /// - Throws: FileManager errors if backup creation fails.
    @discardableResult
    public static func createArchivedBackup(of fileURL: URL) throws -> URL {
        let backupDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtoolskit-backups")

        if !FileManager.default.fileExists(atPath: backupDir.path) {
            try FileManager.default.createDirectory(
                at: backupDir,
                withIntermediateDirectories: true
            )
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let fileName = fileURL.lastPathComponent
        let backupName = "\(timestamp)_\(fileName)"
        let backupURL = backupDir.appendingPathComponent(backupName)

        try FileManager.default.copyItem(at: fileURL, to: backupURL)
        return backupURL
    }

    // MARK: - File System Checks

    /// Checks if a path exists and is a regular file.
    /// - Parameter url: The URL to check.
    /// - Returns: `true` if it exists and is a file.
    public static func isFile(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }
        return !isDirectory.boolValue
    }

    /// Checks if a path exists and is a directory.
    /// - Parameter url: The URL to check.
    /// - Returns: `true` if it exists and is a directory.
    public static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }
        return isDirectory.boolValue
    }

    /// Checks if a path exists (file or directory).
    /// - Parameter url: The URL to check.
    /// - Returns: `true` if it exists.
    public static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}
