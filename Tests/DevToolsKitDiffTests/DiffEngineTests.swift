import Testing
import Foundation
@testable import DevToolsKitDiff

@Suite("DiffTypes")
struct DiffTypesTests {

    @Test func diffLineContent() {
        let context = DiffLine.context("hello")
        let addition = DiffLine.addition("world")
        let deletion = DiffLine.deletion("removed")

        #expect(context.content == "hello")
        #expect(addition.content == "world")
        #expect(deletion.content == "removed")
    }

    @Test func diffLineEquality() {
        #expect(DiffLine.context("a") == DiffLine.context("a"))
        #expect(DiffLine.context("a") != DiffLine.addition("a"))
        #expect(DiffLine.addition("x") == DiffLine.addition("x"))
        #expect(DiffLine.deletion("y") == DiffLine.deletion("y"))
    }

    @Test func diffEquality() {
        let hunk = Hunk(originalStart: 1, originalCount: 1, modifiedStart: 1, modifiedCount: 1, lines: [.context("a")])
        let diff1 = Diff(originalFile: "a.txt", modifiedFile: "b.txt", hunks: [hunk])
        let diff2 = Diff(originalFile: "a.txt", modifiedFile: "b.txt", hunks: [hunk])
        #expect(diff1 == diff2)
    }

    @Test func hunkEquality() {
        let h1 = Hunk(originalStart: 1, originalCount: 2, modifiedStart: 1, modifiedCount: 3, lines: [.addition("x")])
        let h2 = Hunk(originalStart: 1, originalCount: 2, modifiedStart: 1, modifiedCount: 3, lines: [.addition("x")])
        #expect(h1 == h2)
    }
}

@Suite("DiffError")
struct DiffErrorTests {

    @Test func errorDescriptions() {
        let e1 = DiffError.invalidDiff("bad format")
        let e2 = DiffError.applicationFailed("out of range")
        let e3 = DiffError.fileReadFailed("/tmp/missing.txt")
        let e4 = DiffError.fileWriteFailed("/tmp/readonly.txt")

        #expect(e1.errorDescription?.contains("bad format") == true)
        #expect(e2.errorDescription?.contains("out of range") == true)
        #expect(e3.errorDescription?.contains("/tmp/missing.txt") == true)
        #expect(e4.errorDescription?.contains("/tmp/readonly.txt") == true)
    }

    @Test func equality() {
        #expect(DiffError.invalidDiff("a") == DiffError.invalidDiff("a"))
        #expect(DiffError.invalidDiff("a") != DiffError.invalidDiff("b"))
        #expect(DiffError.invalidDiff("a") != DiffError.applicationFailed("a"))
    }
}

@Suite("DiffEngine - Parsing")
struct DiffEngineParsingTests {
    let engine = DiffEngine()

    @Test func parseSimpleDiff() throws {
        let diffText = """
        --- a/file.txt
        +++ b/file.txt
        @@ -1,3 +1,4 @@
         line1
        -line2
        +line2-modified
        +line2b
         line3
        """

        let diff = try engine.parse(diffText)
        #expect(diff.originalFile == "a/file.txt")
        #expect(diff.modifiedFile == "b/file.txt")
        #expect(diff.hunks.count == 1)

        let hunk = diff.hunks[0]
        #expect(hunk.originalStart == 1)
        #expect(hunk.originalCount == 3)
        #expect(hunk.modifiedStart == 1)
        #expect(hunk.modifiedCount == 4)
        #expect(hunk.lines.count == 5)
    }

    @Test func parseMultipleHunks() throws {
        let diffText = """
        --- a/file.txt
        +++ b/file.txt
        @@ -1,2 +1,2 @@
        -old1
        +new1
         same
        @@ -10,2 +10,3 @@
         context
        -removed
        +added1
        +added2
        """

        let diff = try engine.parse(diffText)
        #expect(diff.hunks.count == 2)
        #expect(diff.hunks[0].originalStart == 1)
        #expect(diff.hunks[1].originalStart == 10)
    }

    @Test func parseDiffTooShort() {
        #expect(throws: DiffError.self) {
            try engine.parse("single line")
        }
    }

    @Test func parseInvalidHunkHeader() {
        let diffText = """
        --- a/file.txt
        +++ b/file.txt
        @@ invalid header @@
         line
        """

        #expect(throws: DiffError.self) {
            try engine.parse(diffText)
        }
    }

    @Test func parseAdditionOnly() throws {
        let diffText = """
        --- a/file.txt
        +++ b/file.txt
        @@ -1,1 +1,3 @@
         existing
        +new1
        +new2
        """

        let diff = try engine.parse(diffText)
        let hunk = diff.hunks[0]
        #expect(hunk.lines.count == 3)

        let additions = hunk.lines.filter { if case .addition = $0 { true } else { false } }
        #expect(additions.count == 2)
    }

    @Test func parseDeletionOnly() throws {
        let diffText = """
        --- a/file.txt
        +++ b/file.txt
        @@ -1,3 +1,1 @@
         keep
        -remove1
        -remove2
        """

        let diff = try engine.parse(diffText)
        let hunk = diff.hunks[0]
        let deletions = hunk.lines.filter { if case .deletion = $0 { true } else { false } }
        #expect(deletions.count == 2)
    }
}

@Suite("DiffEngine - Application")
struct DiffEngineApplicationTests {
    let engine = DiffEngine()

    @Test func applyToContent() throws {
        let original = "line1\nline2\nline3"
        let diffText = """
        --- a/file.txt
        +++ b/file.txt
        @@ -1,3 +1,3 @@
         line1
        -line2
        +modified
         line3
        """

        let diff = try engine.parse(diffText)
        let result = try engine.apply(diff, to: original)
        #expect(result == "line1\nmodified\nline3")
    }

    @Test func applyAddition() throws {
        let original = "line1\nline2"
        let diffText = """
        --- a/file.txt
        +++ b/file.txt
        @@ -1,2 +1,3 @@
         line1
        +inserted
         line2
        """

        let diff = try engine.parse(diffText)
        let result = try engine.apply(diff, to: original)
        #expect(result == "line1\ninserted\nline2")
    }

    @Test func applyDeletion() throws {
        let original = "line1\nline2\nline3"
        let diffText = """
        --- a/file.txt
        +++ b/file.txt
        @@ -1,3 +1,2 @@
         line1
        -line2
         line3
        """

        let diff = try engine.parse(diffText)
        let result = try engine.apply(diff, to: original)
        #expect(result == "line1\nline3")
    }

    @Test func applyToFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtoolskit-diff-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let testFile = tempDir.appendingPathComponent("test.txt")
        try "line1\nline2\nline3".write(to: testFile, atomically: true, encoding: .utf8)

        let diffText = """
        --- a/test.txt
        +++ b/test.txt
        @@ -1,3 +1,3 @@
         line1
        -line2
        +changed
         line3
        """

        let diff = try engine.parse(diffText)
        try engine.apply(diff, to: testFile, dryRun: false)

        let result = try String(contentsOf: testFile, encoding: .utf8)
        #expect(result == "line1\nchanged\nline3")

        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test func dryRunDoesNotModify() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("devtoolskit-diff-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let testFile = tempDir.appendingPathComponent("test.txt")
        let originalContent = "line1\nline2\nline3"
        try originalContent.write(to: testFile, atomically: true, encoding: .utf8)

        let diffText = """
        --- a/test.txt
        +++ b/test.txt
        @@ -1,3 +1,3 @@
         line1
        -line2
        +changed
         line3
        """

        let diff = try engine.parse(diffText)
        try engine.apply(diff, to: testFile, dryRun: true)

        let result = try String(contentsOf: testFile, encoding: .utf8)
        #expect(result == originalContent)

        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test func applyToMissingFile() throws {
        let diffText = """
        --- a/file.txt
        +++ b/file.txt
        @@ -1,1 +1,1 @@
        -old
        +new
        """
        let diff = try engine.parse(diffText)
        let missingURL = URL(fileURLWithPath: "/tmp/devtoolskit-nonexistent-\(UUID().uuidString).txt")

        #expect(throws: DiffError.self) {
            try engine.apply(diff, to: missingURL)
        }
    }

    @Test func applyHunkOutOfRange() throws {
        let original = "line1"
        let diffText = """
        --- a/file.txt
        +++ b/file.txt
        @@ -100,1 +100,1 @@
        -old
        +new
        """

        let diff = try engine.parse(diffText)
        #expect(throws: DiffError.self) {
            try engine.apply(diff, to: original)
        }
    }
}

@Suite("DiffEngine - Validation")
struct DiffEngineValidationTests {
    let engine = DiffEngine()

    @Test func validDiffNoWarnings() throws {
        let diffText = """
        --- a/file.txt
        +++ b/file.txt
        @@ -1,1 +1,1 @@
        -old
        +new
        """

        let diff = try engine.parse(diffText)
        let warnings = engine.validate(diff)
        #expect(warnings.isEmpty)
    }

    @Test func emptyHunksWarning() {
        let diff = Diff(originalFile: "a.txt", modifiedFile: "b.txt", hunks: [])
        let warnings = engine.validate(diff)
        #expect(warnings.contains { $0.contains("no hunks") })
    }

    @Test func zeroLineCountsWarning() {
        let hunk = Hunk(
            originalStart: 1, originalCount: 0,
            modifiedStart: 1, modifiedCount: 0,
            lines: [.context("x")]
        )
        let diff = Diff(originalFile: "a.txt", modifiedFile: "b.txt", hunks: [hunk])
        let warnings = engine.validate(diff)
        #expect(warnings.contains { $0.contains("zero line counts") })
    }

    @Test func emptyHunkLinesWarning() {
        let hunk = Hunk(
            originalStart: 1, originalCount: 1,
            modifiedStart: 1, modifiedCount: 1,
            lines: []
        )
        let diff = Diff(originalFile: "a.txt", modifiedFile: "b.txt", hunks: [hunk])
        let warnings = engine.validate(diff)
        #expect(warnings.contains { $0.contains("no lines") })
    }
}
