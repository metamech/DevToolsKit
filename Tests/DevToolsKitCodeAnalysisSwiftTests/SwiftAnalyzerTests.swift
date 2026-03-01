import Testing
import Foundation
@testable import DevToolsKitCodeAnalysis
@testable import DevToolsKitCodeAnalysisSwift

// MARK: - SwiftSpecificRules Tests

@Suite("SwiftSpecificRules - Force Unwraps")
struct ForceUnwrapTests {

    @Test func detectsForceUnwrap() {
        let source = SourceFile(path: "test.swift", content: """
        let value = optional!
        let another = dict["key"]!
        """, language: .swift)

        let issues = SwiftSpecificRules.detectForceUnwraps(source)
        #expect(issues.count >= 1)
        #expect(issues.allSatisfy { $0.code == "SWIFT-001" })
    }

    @Test func ignoresComments() {
        let source = SourceFile(path: "test.swift", content: """
        // let value = optional!
        """, language: .swift)

        let issues = SwiftSpecificRules.detectForceUnwraps(source)
        #expect(issues.isEmpty)
    }

    @Test func ignoresImports() {
        let source = SourceFile(path: "test.swift", content: """
        import Foundation
        """, language: .swift)

        let issues = SwiftSpecificRules.detectForceUnwraps(source)
        #expect(issues.isEmpty)
    }
}

@Suite("SwiftSpecificRules - Implicitly Unwrapped Optionals")
struct IUOTests {

    @Test func detectsIUO() {
        let source = SourceFile(path: "test.swift", content: """
        var name: String!
        let value: Int!
        """, language: .swift)

        let issues = SwiftSpecificRules.detectImplicitlyUnwrappedOptionals(source)
        #expect(issues.count == 2)
        #expect(issues.allSatisfy { $0.code == "SWIFT-002" })
        #expect(issues.allSatisfy { $0.severity == .info })
    }

    @Test func ignoresRegularOptionals() {
        let source = SourceFile(path: "test.swift", content: """
        var name: String?
        let value: Int?
        """, language: .swift)

        let issues = SwiftSpecificRules.detectImplicitlyUnwrappedOptionals(source)
        #expect(issues.isEmpty)
    }
}

@Suite("SwiftSpecificRules - Retain Cycles")
struct RetainCycleTests {

    @Test func detectsRetainCycle() {
        let source = SourceFile(path: "test.swift", content: """
        someFunc { param in
            self.doSomething()
        }
        """, language: .swift)

        let issues = SwiftSpecificRules.detectPotentialRetainCycles(source)
        #expect(issues.count == 1)
        #expect(issues[0].code == "SWIFT-003")
    }

    @Test func noWarningWithWeakSelf() {
        let source = SourceFile(path: "test.swift", content: """
        someFunc { [weak self] param in
            self?.doSomething()
        }
        """, language: .swift)

        let issues = SwiftSpecificRules.detectPotentialRetainCycles(source)
        #expect(issues.isEmpty)
    }

    @Test func noWarningWithUnownedSelf() {
        let source = SourceFile(path: "test.swift", content: """
        someFunc { [unowned self] param in
            self.doSomething()
        }
        """, language: .swift)

        let issues = SwiftSpecificRules.detectPotentialRetainCycles(source)
        #expect(issues.isEmpty)
    }
}

@Suite("SwiftSpecificRules - Empty Catch Blocks")
struct EmptyCatchTests {

    @Test func detectsEmptyCatch() {
        let source = SourceFile(path: "test.swift", content: """
        do {
            try riskyOperation()
        } catch {
        }
        """, language: .swift)

        let issues = SwiftSpecificRules.detectEmptyCatchBlocks(source)
        #expect(issues.count == 1)
        #expect(issues[0].code == "SWIFT-004")
    }

    @Test func noWarningWithHandledCatch() {
        let source = SourceFile(path: "test.swift", content: """
        do {
            try riskyOperation()
        } catch {
            logger.error("Failed: \\(error)")
        }
        """, language: .swift)

        let issues = SwiftSpecificRules.detectEmptyCatchBlocks(source)
        #expect(issues.isEmpty)
    }
}

@Suite("SwiftSpecificRules - Print Statements")
struct PrintStatementTests {

    @Test func detectsPrintStatements() {
        let source = SourceFile(path: "test.swift", content: """
        func doWork() {
            print("Starting work")
            let result = compute()
            print("Done: \\(result)")
        }
        """, language: .swift)

        let issues = SwiftSpecificRules.detectPrintStatements(source)
        #expect(issues.count == 2)
        #expect(issues.allSatisfy { $0.code == "SWIFT-005" })
        #expect(issues.allSatisfy { $0.severity == .info })
    }

    @Test func ignoresCommentedPrints() {
        let source = SourceFile(path: "test.swift", content: """
        // print("debug")
        """, language: .swift)

        let issues = SwiftSpecificRules.detectPrintStatements(source)
        #expect(issues.isEmpty)
    }
}

@Suite("SwiftSpecificRules - TODO/FIXME")
struct TODOTests {

    @Test func detectsTODO() {
        let source = SourceFile(path: "test.swift", content: """
        // TODO: Implement this
        func placeholder() {}
        """, language: .swift)

        let issues = SwiftSpecificRules.detectTODOComments(source)
        #expect(issues.count == 1)
        #expect(issues[0].severity == .info)
    }

    @Test func detectsFIXME() {
        let source = SourceFile(path: "test.swift", content: """
        // FIXME: This is broken
        func broken() {}
        """, language: .swift)

        let issues = SwiftSpecificRules.detectTODOComments(source)
        #expect(issues.count == 1)
        #expect(issues[0].severity == .warning)
    }
}

@Suite("SwiftSpecificRules - Forced Type Casting")
struct ForcedCastTests {

    @Test func detectsForcedCast() {
        let source = SourceFile(path: "test.swift", content: """
        let view = object as! UIView
        """, language: .swift)

        let issues = SwiftSpecificRules.detectForcedTypeCasting(source)
        #expect(issues.count == 1)
        #expect(issues[0].code == "SWIFT-006")
    }

    @Test func ignoresOptionalCast() {
        let source = SourceFile(path: "test.swift", content: """
        let view = object as? UIView
        """, language: .swift)

        let issues = SwiftSpecificRules.detectForcedTypeCasting(source)
        #expect(issues.isEmpty)
    }
}

// MARK: - SwiftAnalyzer Integration Tests

@Suite("SwiftAnalyzer")
struct SwiftAnalyzerTests {

    @Test func analyzesSwiftFile() async throws {
        let analyzer = SwiftAnalyzer()
        let source = SourceFile(path: "test.swift", content: """
        import Foundation

        class MyClass {
            var name: String!  // IUO

            func doWork() {
                let value = optional!  // force unwrap
                print("result: \\(value)")  // print statement
                // TODO: clean this up
            }

            func riskyStuff() {
                do {
                    try something()
                } catch {
                }
            }
        }
        """, language: .swift)

        let result = try await analyzer.analyze(source)
        #expect(result.file == "test.swift")
        #expect(result.language == .swift)
        #expect(!result.issues.isEmpty)
        #expect(result.metrics.linesOfCode > 0)
    }

    @Test func skipsNonSwiftFiles() async throws {
        let analyzer = SwiftAnalyzer()
        let source = SourceFile(path: "test.py", content: """
        def hello():
            print("hello")
        """, language: .python)

        let result = try await analyzer.analyze(source)
        #expect(result.issues.isEmpty)
        #expect(result.metrics.linesOfCode > 0)
    }

    @Test func issuesSortedByLine() async throws {
        let analyzer = SwiftAnalyzer()
        let source = SourceFile(path: "test.swift", content: """
        func test() {
            print("line 2")
            let x = optional!
            print("line 4")
        }
        """, language: .swift)

        let result = try await analyzer.analyze(source)
        let lines = result.issues.map(\.line)
        #expect(lines == lines.sorted())
    }

    @Test func batchAnalysis() async throws {
        let files = [
            SourceFile(path: "a.swift", content: "let x = value!\n", language: .swift),
            SourceFile(path: "b.swift", content: "print(\"hello\")\n", language: .swift),
        ]

        let batch = try await SwiftAnalyzer.analyzeBatch(files)
        #expect(batch.results.count == 2)
        #expect(batch.totalDuration >= 0)
    }
}
