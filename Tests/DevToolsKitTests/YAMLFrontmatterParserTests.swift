import Testing
@testable import DevToolsKit

@Suite("YAMLFrontmatterParser")
struct YAMLFrontmatterParserTests {

    @Test("Parses simple frontmatter")
    func simpleFrontmatter() {
        let content = """
        ---
        title: My Document
        author: Jane
        ---
        # Hello World
        """
        let result = YAMLFrontmatterParser.parse(content)
        #expect(result.frontmatter["title"] == "My Document")
        #expect(result.frontmatter["author"] == "Jane")
        #expect(result.body.contains("# Hello World"))
    }

    @Test("Handles quoted values")
    func quotedValues() {
        let content = """
        ---
        title: "Hello World"
        ---
        Body
        """
        let result = YAMLFrontmatterParser.parse(content)
        #expect(result.frontmatter["title"] == "Hello World")
    }

    @Test("Unescapes quotes in values")
    func escapedQuotes() {
        let content = """
        ---
        title: "Say \\"hello\\""
        ---
        Body
        """
        let result = YAMLFrontmatterParser.parse(content)
        #expect(result.frontmatter["title"] == "Say \"hello\"")
    }

    @Test("Unescapes newlines in values")
    func escapedNewlines() {
        let content = """
        ---
        desc: "line1\\nline2"
        ---
        Body
        """
        let result = YAMLFrontmatterParser.parse(content)
        #expect(result.frontmatter["desc"] == "line1\nline2")
    }

    @Test("No frontmatter returns empty dict and full body")
    func noFrontmatter() {
        let content = "# Just a heading\nSome text"
        let result = YAMLFrontmatterParser.parse(content)
        #expect(result.frontmatter.isEmpty)
        #expect(result.body == content)
    }

    @Test("Unclosed frontmatter returns empty dict")
    func unclosedFrontmatter() {
        let content = """
        ---
        title: Hello
        Body without closing
        """
        let result = YAMLFrontmatterParser.parse(content)
        #expect(result.frontmatter.isEmpty)
        #expect(result.body == content)
    }

    @Test("Skips lines without colons")
    func linesWithoutColons() {
        let content = """
        ---
        title: Test
        no colon here
        author: Bob
        ---
        Body
        """
        let result = YAMLFrontmatterParser.parse(content)
        #expect(result.frontmatter.count == 2)
        #expect(result.frontmatter["title"] == "Test")
        #expect(result.frontmatter["author"] == "Bob")
    }

    @Test("Empty content returns empty result")
    func emptyContent() {
        let result = YAMLFrontmatterParser.parse("")
        #expect(result.frontmatter.isEmpty)
        #expect(result.body == "")
    }

    @Test("Value with colon in it parses correctly")
    func valueWithColon() {
        let content = """
        ---
        url: https://example.com
        ---
        Body
        """
        let result = YAMLFrontmatterParser.parse(content)
        #expect(result.frontmatter["url"] == "https://example.com")
    }
}
