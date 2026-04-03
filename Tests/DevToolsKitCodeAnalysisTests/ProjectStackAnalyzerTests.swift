import Foundation
import Testing
@testable import DevToolsKitCodeAnalysis

@Suite("ProjectStackAnalyzer")
struct ProjectStackAnalyzerTests {

    @Test("Detects Swift + SwiftPM from Package.swift")
    func detectsSwift() async {
        let dir = makeTestDir(files: ["Package.swift", "README.md"])
        let analyzer = ProjectStackAnalyzer(cacheTTL: 0)
        let profile = await analyzer.analyze(directory: dir)
        #expect(profile.languages.contains("Swift"))
        #expect(profile.frameworks.contains("SwiftPM"))
        #expect(profile.hasReadme)
        cleanup(dir)
    }

    @Test("Detects multiple languages")
    func detectsMultiple() async {
        let dir = makeTestDir(files: ["package.json", "go.mod"])
        let analyzer = ProjectStackAnalyzer(cacheTTL: 0)
        let profile = await analyzer.analyze(directory: dir)
        #expect(profile.languages.contains("JavaScript/TypeScript"))
        #expect(profile.languages.contains("Go"))
        cleanup(dir)
    }

    @Test("Detects git repository")
    func detectsGit() async {
        let dir = makeTestDir(files: [])
        try? FileManager.default.createDirectory(
            atPath: (dir as NSString).appendingPathComponent(".git"),
            withIntermediateDirectories: true
        )
        let analyzer = ProjectStackAnalyzer(cacheTTL: 0)
        let profile = await analyzer.analyze(directory: dir)
        #expect(profile.hasGit)
        cleanup(dir)
    }

    @Test("Detects CLAUDE.md")
    func detectsClaudeMd() async {
        let dir = makeTestDir(files: ["CLAUDE.md"])
        let analyzer = ProjectStackAnalyzer(cacheTTL: 0)
        let profile = await analyzer.analyze(directory: dir)
        #expect(profile.hasClaudeMd)
        cleanup(dir)
    }

    @Test("Returns empty profile for nonexistent directory")
    func nonexistentDir() async {
        let analyzer = ProjectStackAnalyzer(cacheTTL: 0)
        let profile = await analyzer.analyze(directory: "/nonexistent/path/\(UUID().uuidString)")
        #expect(profile.languages.isEmpty)
        #expect(profile.frameworks.isEmpty)
        #expect(profile.estimatedFileCount == 0)
    }

    @Test("Cache returns same result within TTL")
    func cacheTTL() async {
        let dir = makeTestDir(files: ["Package.swift"])
        let analyzer = ProjectStackAnalyzer(cacheTTL: 60)
        let first = await analyzer.analyze(directory: dir)
        let second = await analyzer.analyze(directory: dir)
        #expect(first == second)
        cleanup(dir)
    }

    @Test("Invalidate clears cache for directory")
    func invalidate() async {
        let dir = makeTestDir(files: ["Package.swift"])
        let analyzer = ProjectStackAnalyzer(cacheTTL: 60)
        _ = await analyzer.analyze(directory: dir)
        await analyzer.invalidate(directory: dir)
        // After invalidation, re-analysis should work
        let profile = await analyzer.analyze(directory: dir)
        #expect(profile.languages.contains("Swift"))
        cleanup(dir)
    }

    @Test("InvalidateAll clears entire cache")
    func invalidateAll() async {
        let dir = makeTestDir(files: ["go.mod"])
        let analyzer = ProjectStackAnalyzer(cacheTTL: 60)
        _ = await analyzer.analyze(directory: dir)
        await analyzer.invalidateAll()
        let profile = await analyzer.analyze(directory: dir)
        #expect(profile.languages.contains("Go"))
        cleanup(dir)
    }

    @Test("Counts source files")
    func countsFiles() async {
        let dir = makeTestDir(files: [])
        // Create a swift source file
        let swiftFile = (dir as NSString).appendingPathComponent("main.swift")
        try? "print(\"hello\")\n".write(toFile: swiftFile, atomically: true, encoding: .utf8)
        let analyzer = ProjectStackAnalyzer(cacheTTL: 0)
        let profile = await analyzer.analyze(directory: dir)
        #expect(profile.estimatedFileCount >= 1)
        #expect(profile.estimatedLineCount >= 1)
        cleanup(dir)
    }

    // MARK: - Helpers

    private func makeTestDir(files: [String]) -> String {
        let dir = NSTemporaryDirectory() + "psa-test-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for file in files {
            FileManager.default.createFile(
                atPath: (dir as NSString).appendingPathComponent(file),
                contents: nil
            )
        }
        return dir
    }

    private func cleanup(_ dir: String) {
        try? FileManager.default.removeItem(atPath: dir)
    }
}
