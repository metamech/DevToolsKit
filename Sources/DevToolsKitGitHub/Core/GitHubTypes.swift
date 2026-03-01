import Foundation

/// Represents a file or directory in a GitHub repository.
///
/// Since 0.4.0
public struct GitHubFile: Codable, Sendable {
    /// File name.
    public let name: String
    /// File path within the repository.
    public let path: String
    /// Whether this is a file or directory.
    public let type: FileType
    /// Direct download URL for the raw file content.
    public let downloadURL: String?
    /// File size in bytes (nil for directories).
    public let size: Int?
    /// Git SHA of the file.
    public let sha: String?

    enum CodingKeys: String, CodingKey {
        case name, path, type, size, sha
        case downloadURL = "download_url"
    }

    /// Type of GitHub content entry.
    public enum FileType: String, Codable, Sendable {
        /// Regular file.
        case file
        /// Directory.
        case dir
    }

    /// Creates a GitHub file representation.
    public init(name: String, path: String, type: FileType, downloadURL: String? = nil, size: Int? = nil, sha: String? = nil) {
        self.name = name
        self.path = path
        self.type = type
        self.downloadURL = downloadURL
        self.size = size
        self.sha = sha
    }
}

/// Represents a GitHub commit.
///
/// Since 0.4.0
public struct GitHubCommit: Codable, Sendable {
    /// The commit SHA.
    public let sha: String
    /// Commit details.
    public let commit: CommitDetails

    /// Commit detail information.
    public struct CommitDetails: Codable, Sendable {
        /// Commit message.
        public let message: String
        /// Commit author information.
        public let author: Author

        /// Commit author.
        public struct Author: Codable, Sendable {
            /// Author name.
            public let name: String
            /// Author email.
            public let email: String
            /// Commit date string.
            public let date: String
        }
    }
}
