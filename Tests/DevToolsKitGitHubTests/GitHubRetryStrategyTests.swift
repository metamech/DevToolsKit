import Testing
import Foundation
@testable import DevToolsKitGitHub

@Suite("GitHubRetryStrategy")
struct GitHubRetryStrategyTests {

    @Test func retryOnNetworkErrors() async {
        let strategy = GitHubRetryStrategy(maxRetries: 5)

        let timeoutError = URLError(.timedOut)
        let decision = await strategy.shouldRetry(error: timeoutError, attempt: 0)
        guard case .retry(let delay) = decision else {
            Issue.record("Expected retry for timeout error")
            return
        }
        #expect(delay > 0)

        let connectionError = URLError(.networkConnectionLost)
        let decision2 = await strategy.shouldRetry(error: connectionError, attempt: 0)
        guard case .retry = decision2 else {
            Issue.record("Expected retry for connection error")
            return
        }
    }

    @Test func retryOnServerErrors() async {
        let strategy = GitHubRetryStrategy(maxRetries: 5)

        let error500 = GitHubAPIError.httpError(500, "Internal Server Error")
        let decision = await strategy.shouldRetry(error: error500, attempt: 0)
        guard case .retry = decision else {
            Issue.record("Expected retry for 500 error")
            return
        }
    }

    @Test func retryOnRateLimit() async {
        let strategy = GitHubRetryStrategy(maxRetries: 5)

        let rateLimitError = GitHubAPIError.httpError(429, "Too Many Requests")
        let decision = await strategy.shouldRetry(error: rateLimitError, attempt: 0)
        guard case .retry(let delay) = decision else {
            Issue.record("Expected retry for rate limit error")
            return
        }
        #expect(delay >= 54) // 60s base ± 10% jitter
    }

    @Test func noRetryOnClientErrors() async {
        let strategy = GitHubRetryStrategy(maxRetries: 5)

        let error400 = GitHubAPIError.httpError(400, "Bad Request")
        let decision1 = await strategy.shouldRetry(error: error400, attempt: 0)
        #expect(decision1 == .doNotRetry)

        let error404 = GitHubAPIError.httpError(404, "Not Found")
        let decision2 = await strategy.shouldRetry(error: error404, attempt: 0)
        #expect(decision2 == .doNotRetry)
    }

    @Test func maxRetriesEnforcement() async {
        let strategy = GitHubRetryStrategy(maxRetries: 3)
        let error = URLError(.timedOut)

        let decision0 = await strategy.shouldRetry(error: error, attempt: 0)
        let decision1 = await strategy.shouldRetry(error: error, attempt: 1)
        let decision2 = await strategy.shouldRetry(error: error, attempt: 2)

        #expect(decision0 != .doNotRetry)
        #expect(decision1 != .doNotRetry)
        #expect(decision2 != .doNotRetry)

        let decision3 = await strategy.shouldRetry(error: error, attempt: 3)
        #expect(decision3 == .doNotRetry)
    }

    @Test func exponentialBackoff() async {
        let strategy = GitHubRetryStrategy(maxRetries: 5)
        let error = URLError(.timedOut)

        var delays: [TimeInterval] = []
        for attempt in 0..<5 {
            let decision = await strategy.shouldRetry(error: error, attempt: attempt)
            if case .retry(let delay) = decision {
                delays.append(delay)
            }
        }

        #expect(delays.count == 5)
        #expect(delays[0] >= 0.9 && delays[0] <= 1.1)
        #expect(delays[1] >= 1.8 && delays[1] <= 2.2)
        #expect(delays[2] >= 3.6 && delays[2] <= 4.4)
        #expect(delays[3] >= 7.2 && delays[3] <= 8.8)
        #expect(delays[4] <= 17.6)
    }

    @Test func retryOnWrappedNetworkError() async {
        let strategy = GitHubRetryStrategy(maxRetries: 5)
        let networkError = GitHubAPIError.networkError("timeout")
        let decision = await strategy.shouldRetry(error: networkError, attempt: 0)
        guard case .retry = decision else {
            Issue.record("Expected retry for wrapped network error")
            return
        }
    }

    @Test func noRetryOnInvalidURL() async {
        let strategy = GitHubRetryStrategy(maxRetries: 5)
        let error = GitHubAPIError.invalidURL("bad url")
        let decision = await strategy.shouldRetry(error: error, attempt: 0)
        #expect(decision == .doNotRetry)
    }

    @Test func noRetryOnNotFound() async {
        let strategy = GitHubRetryStrategy(maxRetries: 5)
        let error = GitHubAPIError.notFound("resource")
        let decision = await strategy.shouldRetry(error: error, attempt: 0)
        #expect(decision == .doNotRetry)
    }
}
