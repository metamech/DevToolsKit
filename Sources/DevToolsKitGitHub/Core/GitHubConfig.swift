import Foundation

/// Configuration for GitHub API access.
///
/// Since 0.4.0
public struct GitHubConfig: Codable, Sendable {
    /// GitHub personal access token (optional).
    public var token: String?

    /// Enable API response caching to reduce redundant requests.
    public var cacheEnabled: Bool

    /// Cache TTL in seconds (default: 5 minutes).
    public var cacheTTLSeconds: Int

    /// Enable automatic retry on transient failures.
    public var retryEnabled: Bool

    /// Maximum number of retry attempts (default: 5).
    public var maxRetries: Int

    /// Resolved token, checking environment variable first, then config.
    ///
    /// Priority: `GITHUB_TOKEN` env var > `token` property > `nil`.
    public var resolvedToken: String? {
        ProcessInfo.processInfo.environment["GITHUB_TOKEN"] ?? token
    }

    /// Creates a GitHub configuration.
    public init(
        token: String? = nil,
        cacheEnabled: Bool = true,
        cacheTTLSeconds: Int = 300,
        retryEnabled: Bool = true,
        maxRetries: Int = 5
    ) {
        self.token = token
        self.cacheEnabled = cacheEnabled
        self.cacheTTLSeconds = cacheTTLSeconds
        self.retryEnabled = retryEnabled
        self.maxRetries = maxRetries
    }
}
