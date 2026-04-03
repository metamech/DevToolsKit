import Foundation

/// A tiered fuzzy string matcher for search and filtering.
///
/// Matches a query against a candidate string using multiple strategies in
/// decreasing order of specificity. Returns the first (highest-scoring) match found.
///
/// ## Scoring Tiers
///
/// | Tier | Score | Description |
/// |------|-------|-------------|
/// | Exact | 100 | Case-insensitive exact match |
/// | Prefix | 80 | Query matches the start of the candidate |
/// | Word Boundary | 60 | Query matches the start of any word (space, hyphen, underscore, camelCase) |
/// | Substring | 40 | Query appears anywhere in the candidate |
/// | Fuzzy | 20 | All query characters appear in order in the candidate |
///
/// ```swift
/// if let match = FuzzyMatcher.match(query: "fm", against: "FuzzyMatcher") {
///     print(match.score) // 60 (word-boundary match)
/// }
/// ```
///
/// - Since: 0.9.0
public enum FuzzyMatcher {

    /// Match `query` against `candidate` using tiered scoring.
    ///
    /// Returns `nil` if there is no match or if either string is empty.
    ///
    /// - Parameters:
    ///   - query: The search string.
    ///   - candidate: The string to match against.
    /// - Returns: A ``FuzzyMatch`` with the score and matched ranges, or `nil`.
    public static func match(query: String, against candidate: String) -> FuzzyMatch? {
        guard !query.isEmpty, !candidate.isEmpty else { return nil }

        let lowerQuery = query.lowercased()
        let lowerCandidate = candidate.lowercased()

        // Exact match
        if lowerCandidate == lowerQuery {
            let range = candidate.startIndex..<candidate.endIndex
            return FuzzyMatch(score: 100, matchedRanges: [range])
        }

        // Prefix match
        if lowerCandidate.hasPrefix(lowerQuery) {
            let end = candidate.index(candidate.startIndex, offsetBy: query.count)
            return FuzzyMatch(score: 80, matchedRanges: [candidate.startIndex..<end])
        }

        // Word-boundary match
        if let range = wordBoundaryMatch(query: lowerQuery, in: candidate, lowered: lowerCandidate) {
            return FuzzyMatch(score: 60, matchedRanges: [range])
        }

        // Substring match
        if let range = lowerCandidate.range(of: lowerQuery) {
            let start = candidate.index(
                candidate.startIndex,
                offsetBy: lowerCandidate.distance(from: lowerCandidate.startIndex, to: range.lowerBound)
            )
            let end = candidate.index(start, offsetBy: query.count)
            return FuzzyMatch(score: 40, matchedRanges: [start..<end])
        }

        // Fuzzy character-by-character match
        if let ranges = fuzzyCharMatch(query: lowerQuery, in: candidate, lowered: lowerCandidate) {
            return FuzzyMatch(score: 20, matchedRanges: ranges)
        }

        return nil
    }

    // MARK: - Private

    private static func wordBoundaryMatch(
        query: String,
        in candidate: String,
        lowered: String
    ) -> Range<String.Index>? {
        var wordStarts: [String.Index] = [lowered.startIndex]
        var prev: Character = " "
        for idx in lowered.indices {
            let ch = lowered[idx]
            if prev == " " || prev == "-" || prev == "_" {
                if idx != lowered.startIndex {
                    wordStarts.append(idx)
                }
            }
            prev = ch
        }
        // CamelCase boundaries in the original candidate
        for idx in candidate.indices.dropFirst() {
            if candidate[idx].isUppercase && !wordStarts.contains(idx) {
                wordStarts.append(idx)
            }
        }

        for start in wordStarts {
            let substring = lowered[start...]
            if substring.hasPrefix(query) {
                let end = lowered.index(start, offsetBy: query.count)
                return start..<end
            }
        }
        return nil
    }

    private static func fuzzyCharMatch(
        query: String,
        in candidate: String,
        lowered: String
    ) -> [Range<String.Index>]? {
        var ranges: [Range<String.Index>] = []
        var searchStart = lowered.startIndex

        for qChar in query {
            guard searchStart < lowered.endIndex else { return nil }
            let remaining = lowered[searchStart...]
            guard let found = remaining.firstIndex(of: qChar) else { return nil }
            let next = lowered.index(after: found)
            ranges.append(found..<next)
            searchStart = next
        }

        return ranges.isEmpty ? nil : ranges
    }
}
