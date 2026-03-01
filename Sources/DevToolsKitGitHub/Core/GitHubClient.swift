import Foundation
import os

/// GitHub API client with caching, retry, and rate limit support.
///
/// ```swift
/// let config = GitHubConfig(token: "ghp_...")
/// let client = GitHubClient(config: config)
///
/// let files = try await client.listDirectory(owner: "apple", repo: "swift", path: "Sources")
/// let data = try await client.downloadRawFile(owner: "apple", repo: "swift", path: "README.md")
/// ```
///
/// Since 0.4.0
public actor GitHubClient {
    private let config: GitHubConfig
    private let session: URLSession
    private let cache: GitHubAPICache
    private let retryStrategy: GitHubRetryStrategy
    private let baseURL = "https://api.github.com"
    private let rawBaseURL = "https://raw.githubusercontent.com"

    private let logger = Logger(
        subsystem: "com.devtoolskit.github",
        category: "GitHubClient"
    )

    /// Creates a GitHub client.
    /// - Parameters:
    ///   - config: GitHub API configuration.
    ///   - session: URL session to use (defaults to `.shared`).
    ///   - cache: API response cache.
    ///   - retryStrategy: Retry strategy for transient failures.
    public init(
        config: GitHubConfig = GitHubConfig(),
        session: URLSession = .shared,
        cache: GitHubAPICache? = nil,
        retryStrategy: GitHubRetryStrategy? = nil
    ) {
        self.config = config
        self.session = session
        self.cache = cache ?? GitHubAPICache()
        self.retryStrategy = retryStrategy ?? GitHubRetryStrategy(maxRetries: config.maxRetries)
    }

    // MARK: - Authentication

    private nonisolated func createAuthenticatedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let token = config.resolvedToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private nonisolated func checkRateLimitHeaders(_ response: HTTPURLResponse) throws {
        if let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
           let remainingInt = Int(remaining), remainingInt == 0 {
            let resetDate: Date? = {
                if let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset"),
                   let timestamp = TimeInterval(reset) {
                    return Date(timeIntervalSince1970: timestamp)
                }
                return nil
            }()
            throw GitHubAPIError.rateLimitExceeded(resetDate: resetDate)
        }
    }

    private nonisolated func determineTTL(endpoint: String) -> TimeInterval {
        switch endpoint {
        case _ where endpoint.contains("/repos/") && endpoint.contains("/commits/"):
            return 300
        case _ where endpoint.contains("/repos/") && !endpoint.contains("/contents/"):
            return 3600
        case _ where endpoint.contains("/contents/"):
            return 300
        default:
            return TimeInterval(config.cacheTTLSeconds)
        }
    }

    private nonisolated func extractHeaders(_ response: HTTPURLResponse) -> [String: String] {
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                headers[key] = value
            }
        }
        return headers
    }

    private func executeWithRetry<T: Sendable>(
        operation: @Sendable () async throws -> T,
        endpoint: String
    ) async throws -> T {
        guard config.retryEnabled else {
            return try await operation()
        }

        var lastError: (any Error)?

        for attempt in 0..<config.maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                let decision = await retryStrategy.shouldRetry(error: error, attempt: attempt)
                switch decision {
                case .retry(let delay):
                    logger.warning("Request failed, retrying (\(attempt + 1)/\(self.config.maxRetries)) after \(String(format: "%.1f", delay))s")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                case .doNotRetry:
                    throw error
                }
            }
        }

        throw lastError!
    }

    // MARK: - Raw File Operations

    /// Download raw file content from GitHub.
    /// - Parameters:
    ///   - owner: Repository owner.
    ///   - repo: Repository name.
    ///   - path: File path within the repository.
    ///   - ref: Git reference (branch, tag, or SHA). Defaults to `"main"`.
    /// - Returns: The file data.
    public func downloadRawFile(
        owner: String,
        repo: String,
        path: String,
        ref: String = "main"
    ) async throws -> Data {
        let endpoint = "/\(owner)/\(repo)/\(ref)/\(path)"
        return try await executeWithRetry(operation: {
            let urlString = "\(self.rawBaseURL)\(endpoint)"
            guard let url = URL(string: urlString) else {
                throw GitHubAPIError.invalidURL(urlString)
            }

            do {
                let (data, response) = try await self.session.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GitHubAPIError.invalidResponse
                }

                switch httpResponse.statusCode {
                case 200:
                    return data
                case 404:
                    throw GitHubAPIError.notFound("\(owner)/\(repo)/\(path)")
                case 403:
                    throw GitHubAPIError.rateLimitExceeded(resetDate: nil)
                default:
                    throw GitHubAPIError.httpError(httpResponse.statusCode, "Failed to download file")
                }
            } catch let error as GitHubAPIError {
                throw error
            } catch {
                throw GitHubAPIError.networkError(error.localizedDescription)
            }
        }, endpoint: endpoint)
    }

    // MARK: - Repository Operations

    /// Check if a repository exists.
    /// - Parameters:
    ///   - owner: Repository owner.
    ///   - repo: Repository name.
    /// - Returns: `true` if the repository exists.
    public func repositoryExists(owner: String, repo: String) async throws -> Bool {
        let endpoint = "/repos/\(owner)/\(repo)"
        let urlString = "\(baseURL)\(endpoint)"

        guard let url = URL(string: urlString) else {
            throw GitHubAPIError.invalidURL(urlString)
        }

        if config.cacheEnabled {
            let cacheKey = await cache.cacheKey(method: "GET", endpoint: endpoint)
            if await cache.get(key: cacheKey) != nil {
                return true
            }
        }

        return try await executeWithRetry(operation: {
            do {
                let request = self.createAuthenticatedRequest(url: url)
                let (data, response) = try await self.session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GitHubAPIError.invalidResponse
                }
                try self.checkRateLimitHeaders(httpResponse)
                let exists = httpResponse.statusCode == 200

                if exists && self.config.cacheEnabled {
                    let ttl = self.determineTTL(endpoint: endpoint)
                    let cacheKey = await self.cache.cacheKey(method: "GET", endpoint: endpoint)
                    let headers = self.extractHeaders(httpResponse)
                    await self.cache.set(key: cacheKey, data: data, ttl: ttl, headers: headers)
                }

                return exists
            } catch let error as GitHubAPIError {
                throw error
            } catch {
                return false
            }
        }, endpoint: endpoint)
    }

    /// Get the latest commit SHA for a branch.
    /// - Parameters:
    ///   - owner: Repository owner.
    ///   - repo: Repository name.
    ///   - ref: Git reference. Defaults to `"main"`.
    /// - Returns: The commit SHA string.
    public func getLatestCommit(
        owner: String,
        repo: String,
        ref: String = "main"
    ) async throws -> String {
        let endpoint = "/repos/\(owner)/\(repo)/commits/\(ref)"
        let urlString = "\(baseURL)\(endpoint)"

        guard let url = URL(string: urlString) else {
            throw GitHubAPIError.invalidURL(urlString)
        }

        if config.cacheEnabled {
            let cacheKey = await cache.cacheKey(method: "GET", endpoint: endpoint)
            if let cached = await cache.get(key: cacheKey) {
                let commit = try JSONDecoder().decode(GitHubCommit.self, from: cached.data)
                return commit.sha
            }
        }

        return try await executeWithRetry(operation: {
            do {
                let request = self.createAuthenticatedRequest(url: url)
                let (data, response) = try await self.session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GitHubAPIError.invalidResponse
                }
                try self.checkRateLimitHeaders(httpResponse)

                switch httpResponse.statusCode {
                case 200:
                    let commit = try JSONDecoder().decode(GitHubCommit.self, from: data)
                    if self.config.cacheEnabled {
                        let ttl = self.determineTTL(endpoint: endpoint)
                        let cacheKey = await self.cache.cacheKey(method: "GET", endpoint: endpoint)
                        let headers = self.extractHeaders(httpResponse)
                        await self.cache.set(key: cacheKey, data: data, ttl: ttl, headers: headers)
                    }
                    return commit.sha
                case 404:
                    throw GitHubAPIError.notFound("\(owner)/\(repo)@\(ref)")
                case 403:
                    throw GitHubAPIError.rateLimitExceeded(resetDate: nil)
                default:
                    throw GitHubAPIError.httpError(httpResponse.statusCode, "Failed to get commit")
                }
            } catch let error as DecodingError {
                throw GitHubAPIError.decodingError(error.localizedDescription)
            } catch let error as GitHubAPIError {
                throw error
            } catch {
                throw GitHubAPIError.networkError(error.localizedDescription)
            }
        }, endpoint: endpoint)
    }

    /// List files in a directory.
    /// - Parameters:
    ///   - owner: Repository owner.
    ///   - repo: Repository name.
    ///   - path: Directory path within the repository.
    ///   - ref: Git reference. Defaults to `"main"`.
    /// - Returns: Array of files and directories.
    public func listDirectory(
        owner: String,
        repo: String,
        path: String,
        ref: String = "main"
    ) async throws -> [GitHubFile] {
        let endpoint = "/repos/\(owner)/\(repo)/contents/\(path)"
        let urlString = "\(baseURL)\(endpoint)?ref=\(ref)"

        guard let url = URL(string: urlString) else {
            throw GitHubAPIError.invalidURL(urlString)
        }

        if config.cacheEnabled {
            let cacheKey = await cache.cacheKey(method: "GET", endpoint: endpoint, params: ["ref": ref])
            if let cached = await cache.get(key: cacheKey) {
                let files = try JSONDecoder().decode([GitHubFile].self, from: cached.data)
                return files
            }
        }

        return try await executeWithRetry(operation: {
            do {
                let request = self.createAuthenticatedRequest(url: url)
                let (data, response) = try await self.session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GitHubAPIError.invalidResponse
                }
                try self.checkRateLimitHeaders(httpResponse)

                switch httpResponse.statusCode {
                case 200:
                    let files = try JSONDecoder().decode([GitHubFile].self, from: data)
                    if self.config.cacheEnabled {
                        let ttl = self.determineTTL(endpoint: endpoint)
                        let cacheKey = await self.cache.cacheKey(method: "GET", endpoint: endpoint, params: ["ref": ref])
                        let headers = self.extractHeaders(httpResponse)
                        await self.cache.set(key: cacheKey, data: data, ttl: ttl, headers: headers)
                    }
                    return files
                case 404:
                    throw GitHubAPIError.notFound("\(owner)/\(repo)/\(path)")
                case 403:
                    throw GitHubAPIError.rateLimitExceeded(resetDate: nil)
                default:
                    throw GitHubAPIError.httpError(httpResponse.statusCode, "Failed to list directory")
                }
            } catch let error as DecodingError {
                throw GitHubAPIError.decodingError(error.localizedDescription)
            } catch let error as GitHubAPIError {
                throw error
            } catch {
                throw GitHubAPIError.networkError(error.localizedDescription)
            }
        }, endpoint: endpoint)
    }

    // MARK: - Utility Methods

    /// Download multiple files in parallel.
    /// - Parameters:
    ///   - owner: Repository owner.
    ///   - repo: Repository name.
    ///   - paths: Array of file paths.
    ///   - ref: Git reference. Defaults to `"main"`.
    /// - Returns: Dictionary mapping paths to their downloaded data.
    public func downloadFiles(
        owner: String,
        repo: String,
        paths: [String],
        ref: String = "main"
    ) async throws -> [String: Data] {
        try await withThrowingTaskGroup(of: (String, Data).self) { group in
            var results: [String: Data] = [:]
            for path in paths {
                group.addTask {
                    let data = try await self.downloadRawFile(
                        owner: owner, repo: repo, path: path, ref: ref
                    )
                    return (path, data)
                }
            }
            for try await (path, data) in group {
                results[path] = data
            }
            return results
        }
    }

    /// Get the current cache statistics.
    /// - Returns: Cache count and expired entry count.
    public func cacheStats() async -> (count: Int, expiredCount: Int) {
        await cache.stats()
    }
}
