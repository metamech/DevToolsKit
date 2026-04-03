import Foundation

/// The result of a fuzzy match operation, containing the score and matched ranges.
///
/// Scores are tiered:
/// - 100: Exact match
/// - 80: Prefix match
/// - 60: Word-boundary match
/// - 40: Substring match
/// - 20: Fuzzy character-by-character match
///
/// - Since: 0.9.0
public struct FuzzyMatch: Sendable {
    /// The match score (higher is better). See ``FuzzyMatcher`` for tier values.
    public let score: Int

    /// The ranges in the candidate string that matched the query.
    public let matchedRanges: [Range<String.Index>]

    /// Creates a fuzzy match result.
    ///
    /// - Parameters:
    ///   - score: The match score.
    ///   - matchedRanges: The ranges in the candidate string that matched.
    public init(score: Int, matchedRanges: [Range<String.Index>]) {
        self.score = score
        self.matchedRanges = matchedRanges
    }
}
