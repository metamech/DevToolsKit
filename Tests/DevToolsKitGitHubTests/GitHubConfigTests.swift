import Testing
import Foundation
@testable import DevToolsKitGitHub

@Suite("GitHubConfig")
struct GitHubConfigTests {

    @Test func defaultValues() {
        let config = GitHubConfig()
        #expect(config.token == nil)
        #expect(config.cacheEnabled == true)
        #expect(config.cacheTTLSeconds == 300)
        #expect(config.retryEnabled == true)
        #expect(config.maxRetries == 5)
    }

    @Test func customValues() {
        let config = GitHubConfig(
            token: "test_token",
            cacheEnabled: false,
            cacheTTLSeconds: 600,
            retryEnabled: false,
            maxRetries: 3
        )
        #expect(config.token == "test_token")
        #expect(config.cacheEnabled == false)
        #expect(config.cacheTTLSeconds == 600)
        #expect(config.retryEnabled == false)
        #expect(config.maxRetries == 3)
    }

    @Test func isCodable() throws {
        let config = GitHubConfig(
            token: "ghp_test123",
            cacheEnabled: true,
            cacheTTLSeconds: 300,
            retryEnabled: true,
            maxRetries: 5
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(GitHubConfig.self, from: data)
        #expect(decoded.token == config.token)
        #expect(decoded.cacheEnabled == config.cacheEnabled)
        #expect(decoded.cacheTTLSeconds == config.cacheTTLSeconds)
        #expect(decoded.retryEnabled == config.retryEnabled)
        #expect(decoded.maxRetries == config.maxRetries)
    }

    @Test func codableWithNilToken() throws {
        let config = GitHubConfig()
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(GitHubConfig.self, from: data)
        #expect(decoded.token == nil)
    }

    @Test func resolvedTokenFallsBackToConfig() {
        let config = GitHubConfig(token: "config_token")
        // If GITHUB_TOKEN env var is not set, should fall back to config
        if ProcessInfo.processInfo.environment["GITHUB_TOKEN"] == nil {
            #expect(config.resolvedToken == "config_token")
        }
    }

    @Test func cacheTTLVariations() {
        #expect(GitHubConfig(cacheTTLSeconds: 60).cacheTTLSeconds == 60)
        #expect(GitHubConfig(cacheTTLSeconds: 300).cacheTTLSeconds == 300)
        #expect(GitHubConfig(cacheTTLSeconds: 3600).cacheTTLSeconds == 3600)
    }

    @Test func maxRetriesVariations() {
        #expect(GitHubConfig(maxRetries: 1).maxRetries == 1)
        #expect(GitHubConfig(maxRetries: 3).maxRetries == 3)
        #expect(GitHubConfig(maxRetries: 10).maxRetries == 10)
    }
}
