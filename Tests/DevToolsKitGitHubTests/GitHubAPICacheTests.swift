import Testing
import Foundation
@testable import DevToolsKitGitHub

@Suite("GitHubAPICache")
struct GitHubAPICacheTests {

    @Test func cacheKeyGeneration() async {
        let cache = GitHubAPICache()
        let key1 = await cache.cacheKey(method: "GET", endpoint: "/repos/owner/repo")
        #expect(key1 == "GET:/repos/owner/repo")

        let key2 = await cache.cacheKey(method: "GET", endpoint: "/repos/owner/repo/commits", params: ["ref": "main"])
        #expect(key2 == "GET:/repos/owner/repo/commits?ref=main")

        let key3 = await cache.cacheKey(method: "GET", endpoint: "/test", params: ["z": "last", "a": "first"])
        #expect(key3 == "GET:/test?a=first&z=last")
    }

    @Test func setAndGet() async {
        let cache = GitHubAPICache()
        let testData = "test data".data(using: .utf8)!
        let key = "GET:/test"

        await cache.set(key: key, data: testData, ttl: 300, headers: ["X-Test": "value"])
        let entry = await cache.get(key: key)
        #expect(entry != nil)
        #expect(entry?.data == testData)
        #expect(entry?.headers["X-Test"] == "value")
    }

    @Test func cacheExpiration() async throws {
        let cache = GitHubAPICache()
        let testData = "test data".data(using: .utf8)!
        let key = "GET:/test"

        await cache.set(key: key, data: testData, ttl: 0.1)
        let entry1 = await cache.get(key: key)
        #expect(entry1 != nil)

        try await Task.sleep(nanoseconds: 200_000_000)
        let entry2 = await cache.get(key: key)
        #expect(entry2 == nil)
    }

    @Test func cacheEviction() async {
        let cache = GitHubAPICache()
        for i in 0..<1010 {
            let key = "GET:/test/\(i)"
            let data = "data\(i)".data(using: .utf8)!
            await cache.set(key: key, data: data, ttl: 300)
        }
        let stats = await cache.stats()
        #expect(stats.count <= 1000)
    }

    @Test func cacheInvalidation() async {
        let cache = GitHubAPICache()
        await cache.set(key: "GET:/repos/owner1/repo", data: "data1".data(using: .utf8)!, ttl: 300)
        await cache.set(key: "GET:/repos/owner2/repo", data: "data2".data(using: .utf8)!, ttl: 300)
        await cache.set(key: "GET:/other/path", data: "data3".data(using: .utf8)!, ttl: 300)

        await cache.invalidate(prefix: "GET:/repos/")

        let entry1 = await cache.get(key: "GET:/repos/owner1/repo")
        let entry2 = await cache.get(key: "GET:/repos/owner2/repo")
        let entry3 = await cache.get(key: "GET:/other/path")

        #expect(entry1 == nil)
        #expect(entry2 == nil)
        #expect(entry3 != nil)
    }

    @Test func cacheClear() async {
        let cache = GitHubAPICache()
        await cache.set(key: "GET:/test1", data: "data1".data(using: .utf8)!, ttl: 300)
        await cache.set(key: "GET:/test2", data: "data2".data(using: .utf8)!, ttl: 300)
        await cache.clear()
        let stats = await cache.stats()
        #expect(stats.count == 0)
    }

    @Test func cacheStats() async throws {
        let cache = GitHubAPICache()
        await cache.set(key: "GET:/active", data: "data".data(using: .utf8)!, ttl: 300)
        await cache.set(key: "GET:/expired", data: "data".data(using: .utf8)!, ttl: 0.1)
        try await Task.sleep(nanoseconds: 200_000_000)
        let stats = await cache.stats()
        #expect(stats.count == 2)
        #expect(stats.expiredCount == 1)
    }

    @Test func evictExpired() async throws {
        let cache = GitHubAPICache()
        for i in 0..<10 {
            await cache.set(key: "GET:/expired/\(i)", data: "data".data(using: .utf8)!, ttl: 0.1)
        }
        for i in 0..<5 {
            await cache.set(key: "GET:/active/\(i)", data: "data".data(using: .utf8)!, ttl: 300)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        await cache.evictExpired()
        let stats = await cache.stats()
        #expect(stats.count == 5)
    }

    @Test func configurableMaxEntries() async {
        let cache = GitHubAPICache(maxEntries: 5)
        for i in 0..<10 {
            await cache.set(key: "GET:/test/\(i)", data: "data".data(using: .utf8)!, ttl: 300)
        }
        let stats = await cache.stats()
        #expect(stats.count <= 5)
    }
}
