import Foundation

/// Thread-safe in-memory cache for GitHub API responses.
///
/// Since 0.4.0
public actor GitHubAPICache {
    private var cache: [String: CacheEntry] = [:]
    private let maxEntries: Int

    /// A cached API response entry.
    public struct CacheEntry: Sendable {
        /// Cached response data.
        public let data: Data
        /// When this entry was cached.
        public let cachedAt: Date
        /// Time-to-live in seconds.
        public let ttl: TimeInterval
        /// Response headers from the original request.
        public let headers: [String: String]

        /// Whether this entry has expired.
        public var isExpired: Bool {
            Date().timeIntervalSince(cachedAt) > ttl
        }
    }

    /// Creates a new API cache.
    /// - Parameter maxEntries: Maximum number of entries to store (default: 1000).
    public init(maxEntries: Int = 1000) {
        self.maxEntries = maxEntries
    }

    /// Generate cache key from HTTP method, endpoint, and parameters.
    /// - Parameters:
    ///   - method: HTTP method.
    ///   - endpoint: API endpoint path.
    ///   - params: Query parameters.
    /// - Returns: A unique cache key string.
    public func cacheKey(method: String, endpoint: String, params: [String: String] = [:]) -> String {
        let sortedParams = params.sorted(by: { $0.key < $1.key })
        let paramString = sortedParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        return "\(method):\(endpoint)\(paramString.isEmpty ? "" : "?\(paramString)")"
    }

    /// Get cached entry if it exists and is not expired.
    /// - Parameter key: Cache key.
    /// - Returns: The cache entry if valid, or `nil`.
    public func get(key: String) -> CacheEntry? {
        guard let entry = cache[key], !entry.isExpired else {
            cache.removeValue(forKey: key)
            return nil
        }
        return entry
    }

    /// Store data in cache with TTL.
    /// - Parameters:
    ///   - key: Cache key.
    ///   - data: Response data.
    ///   - ttl: Time-to-live in seconds.
    ///   - headers: Response headers.
    public func set(key: String, data: Data, ttl: TimeInterval, headers: [String: String] = [:]) {
        if cache.count >= maxEntries {
            evictExpired()
        }
        if cache.count >= maxEntries {
            let oldest = cache.min(by: { $0.value.cachedAt < $1.value.cachedAt })
            if let oldest {
                cache.removeValue(forKey: oldest.key)
            }
        }
        cache[key] = CacheEntry(data: data, cachedAt: Date(), ttl: ttl, headers: headers)
    }

    /// Invalidate all cache entries matching a prefix.
    /// - Parameter prefix: Key prefix to invalidate.
    public func invalidate(prefix: String) {
        cache = cache.filter { !$0.key.hasPrefix(prefix) }
    }

    /// Clear all cached entries.
    public func clear() {
        cache.removeAll()
    }

    /// Remove expired entries.
    public func evictExpired() {
        cache = cache.filter { !$0.value.isExpired }
    }

    /// Get cache statistics.
    /// - Returns: Total count and expired entry count.
    public func stats() -> (count: Int, expiredCount: Int) {
        let expired = cache.values.filter { $0.isExpired }.count
        return (cache.count, expired)
    }
}
