[< Guide](GUIDE.md) | [Index](../INDEX.md)

# DevToolsKitGitHub API Reference

> Source: `Sources/DevToolsKitGitHub/`
> Since: 0.4.0

## GitHubConfig
```swift
public struct GitHubConfig: Codable, Sendable {
    public var token: String?
    public var cacheEnabled: Bool
    public var cacheTTLSeconds: Int
    public var retryEnabled: Bool
    public var maxRetries: Int
    public var resolvedToken: String? { get }
}
```

## GitHubClient
```swift
public actor GitHubClient {
    public init(config: GitHubConfig, session: URLSession, cache: GitHubAPICache?, retryStrategy: GitHubRetryStrategy?)
    public func downloadRawFile(owner: String, repo: String, path: String, ref: String) async throws -> Data
    public func repositoryExists(owner: String, repo: String) async throws -> Bool
    public func getLatestCommit(owner: String, repo: String, ref: String) async throws -> String
    public func listDirectory(owner: String, repo: String, path: String, ref: String) async throws -> [GitHubFile]
    public func downloadFiles(owner: String, repo: String, paths: [String], ref: String) async throws -> [String: Data]
    public func cacheStats() async -> (count: Int, expiredCount: Int)
}
```

## GitHubAPIError
```swift
public enum GitHubAPIError: Error, LocalizedError, Sendable {
    case invalidURL(String)
    case httpError(Int, String)
    case notFound(String)
    case rateLimitExceeded(resetDate: Date?)
    case networkError(String)
    case invalidResponse
    case decodingError(String)
}
```

## GitHubAPICache
```swift
public actor GitHubAPICache {
    public init(maxEntries: Int = 1000)
    public func cacheKey(method: String, endpoint: String, params: [String: String]) -> String
    public func get(key: String) -> CacheEntry?
    public func set(key: String, data: Data, ttl: TimeInterval, headers: [String: String])
    public func invalidate(prefix: String)
    public func clear()
    public func evictExpired()
    public func stats() -> (count: Int, expiredCount: Int)
}
```

## GitHubRetryStrategy
```swift
public actor GitHubRetryStrategy {
    public init(maxRetries: Int = 5)
    public func shouldRetry(error: Error, attempt: Int) -> RetryDecision
}
```

## Types
```swift
public struct GitHubFile: Codable, Sendable
public struct GitHubCommit: Codable, Sendable
```

## Panel
```swift
public struct GitHubStatusPanel: DevToolPanel {
    public let id = "devtools.github"
    public init(client: GitHubClient)
}
```
