import Testing
@testable import DevToolsKit

@Suite("FuzzyMatcher")
struct FuzzyMatcherTests {

    @Test("Exact match scores 100")
    func exactMatch() {
        let result = FuzzyMatcher.match(query: "Hello", against: "hello")
        #expect(result?.score == 100)
    }

    @Test("Prefix match scores 80")
    func prefixMatch() {
        let result = FuzzyMatcher.match(query: "Hel", against: "Hello World")
        #expect(result?.score == 80)
    }

    @Test("Word boundary match scores 60")
    func wordBoundaryMatch() {
        let result = FuzzyMatcher.match(query: "wor", against: "Hello World")
        #expect(result?.score == 60)
    }

    @Test("CamelCase word boundary match scores 60")
    func camelCaseBoundary() {
        let result = FuzzyMatcher.match(query: "mat", against: "FuzzyMatcher")
        #expect(result?.score == 60)
    }

    @Test("Substring match scores 40")
    func substringMatch() {
        let result = FuzzyMatcher.match(query: "llo", against: "Hello")
        #expect(result?.score == 40)
    }

    @Test("Fuzzy character match scores 20")
    func fuzzyMatch() {
        let result = FuzzyMatcher.match(query: "hw", against: "Hello World")
        #expect(result?.score == 20)
    }

    @Test("No match returns nil")
    func noMatch() {
        let result = FuzzyMatcher.match(query: "xyz", against: "Hello")
        #expect(result == nil)
    }

    @Test("Empty query returns nil")
    func emptyQuery() {
        let result = FuzzyMatcher.match(query: "", against: "Hello")
        #expect(result == nil)
    }

    @Test("Empty candidate returns nil")
    func emptyCandidate() {
        let result = FuzzyMatcher.match(query: "Hello", against: "")
        #expect(result == nil)
    }

    @Test("Hyphen word boundary")
    func hyphenBoundary() {
        let result = FuzzyMatcher.match(query: "bar", against: "foo-bar")
        #expect(result?.score == 60)
    }

    @Test("Underscore word boundary")
    func underscoreBoundary() {
        let result = FuzzyMatcher.match(query: "bar", against: "foo_bar")
        #expect(result?.score == 60)
    }

    @Test("Matched ranges are non-empty for all tiers")
    func matchedRangesPresent() {
        let exact = FuzzyMatcher.match(query: "test", against: "test")
        #expect(exact?.matchedRanges.isEmpty == false)

        let prefix = FuzzyMatcher.match(query: "te", against: "test")
        #expect(prefix?.matchedRanges.isEmpty == false)

        let fuzzy = FuzzyMatcher.match(query: "tt", against: "test")
        #expect(fuzzy?.matchedRanges.isEmpty == false)
    }

    @Test("Case insensitive matching")
    func caseInsensitive() {
        let result = FuzzyMatcher.match(query: "HELLO", against: "hello")
        #expect(result?.score == 100)
    }
}
