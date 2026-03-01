import Foundation

/// Retry strategy with exponential backoff and jitter for GitHub API requests.
///
/// Since 0.4.0
public actor GitHubRetryStrategy {
    private let maxRetries: Int
    private let baseDelay: TimeInterval = 1.0
    private let maxDelay: TimeInterval = 16.0

    /// Decision on whether to retry a failed request.
    public enum RetryDecision: Sendable, Equatable {
        /// Retry after the specified delay.
        case retry(after: TimeInterval)
        /// Do not retry.
        case doNotRetry
    }

    /// Creates a retry strategy.
    /// - Parameter maxRetries: Maximum number of retry attempts (default: 5).
    public init(maxRetries: Int = 5) {
        self.maxRetries = maxRetries
    }

    /// Determine if an error should be retried and calculate delay.
    /// - Parameters:
    ///   - error: The error that occurred.
    ///   - attempt: Current attempt number (0-based).
    /// - Returns: Whether to retry and the delay.
    public func shouldRetry(error: Error, attempt: Int) -> RetryDecision {
        guard attempt < maxRetries else {
            return .doNotRetry
        }

        if isRetryable(error) {
            let delay = calculateDelay(attempt: attempt, error: error)
            return .retry(after: delay)
        }

        return .doNotRetry
    }

    private func isRetryable(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                 .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }

        if let apiError = error as? GitHubAPIError {
            switch apiError {
            case .httpError(let code, _):
                return code >= 500 || code == 429
            case .networkError:
                return true
            default:
                return false
            }
        }

        return false
    }

    private func calculateDelay(attempt: Int, error: Error) -> TimeInterval {
        let isRateLimit = { () -> Bool in
            if case .httpError(429, _) = error as? GitHubAPIError {
                return true
            }
            return false
        }()

        let base: TimeInterval = isRateLimit ? 60.0 : baseDelay
        let exponentialDelay = base * pow(2.0, Double(attempt))
        let cappedDelay = isRateLimit ? exponentialDelay : min(exponentialDelay, maxDelay)
        let jitter = Double.random(in: -0.1...0.1) * cappedDelay
        return cappedDelay + jitter
    }
}
