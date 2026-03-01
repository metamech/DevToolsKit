import Foundation

/// Errors specific to GitHub API operations.
///
/// Since 0.4.0
public enum GitHubAPIError: Error, LocalizedError, Sendable {
    /// The URL was invalid.
    case invalidURL(String)
    /// HTTP error with status code and message.
    case httpError(Int, String)
    /// The requested resource was not found.
    case notFound(String)
    /// GitHub API rate limit exceeded.
    case rateLimitExceeded(resetDate: Date?)
    /// A network-level error occurred.
    case networkError(String)
    /// The response was not valid.
    case invalidResponse
    /// Failed to decode the response.
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .httpError(let code, let message):
            return "HTTP error \(code): \(message)"
        case .notFound(let resource):
            return "Not found: \(resource)"
        case .rateLimitExceeded(let resetDate):
            var msg = "GitHub API rate limit exceeded"
            if let reset = resetDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .none
                formatter.timeStyle = .short
                msg += " (resets at \(formatter.string(from: reset)))"
            }
            msg += ". Set GITHUB_TOKEN environment variable to increase limit from 60/hour to 5000/hour."
            return msg
        case .networkError(let description):
            return "Network error: \(description)"
        case .invalidResponse:
            return "Invalid response from GitHub API"
        case .decodingError(let description):
            return "Failed to decode response: \(description)"
        }
    }
}
