import Foundation
import Testing
@testable import DevToolsKitCodeAnalysis

@Suite("Performance Analyzer")
struct PerformanceAnalyzerTests {

    // MARK: - Nested Loops Tests

    @Test("Detects nested loops")
    func nestedLoops() {
        let code = """
        for i in 0..<10 {
            for j in 0..<10 {
                print(i, j)
            }
        }
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let issues = PerformancePatterns.detectNestedLoops(in: file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.code == "PERF-001" })
        #expect(issues.contains { $0.category == .performance })
    }

    @Test("Detects triple nested loops")
    func tripleNestedLoops() {
        let code = """
        for i in array1 {
            for j in array2 {
                for k in array3 {
                    process(i, j, k)
                }
            }
        }
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let issues = PerformancePatterns.detectNestedLoops(in: file)

        #expect(issues.count >= 2)
    }

    // MARK: - String Concatenation Tests

    @Test("Detects string concatenation in loop with +=")
    func stringConcatInLoop() {
        let code = """
        for item in items {
            result += "text"
        }
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let issues = PerformancePatterns.detectStringConcatInLoop(in: file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.code == "PERF-002" })
    }

    @Test("Detects string concatenation in loop with +")
    func stringConcatWithPlus() {
        let code = """
        for name in names {
            let message = "Hello " + name
        }
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let issues = PerformancePatterns.detectStringConcatInLoop(in: file)

        #expect(!issues.isEmpty)
    }

    // MARK: - Array Append Tests

    @Test("Detects array append without capacity reservation")
    func arrayAppendWithoutCapacity() {
        let code = """
        var results: [Int] = []
        for i in 0..<1000 {
            results.append(i)
        }
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let issues = PerformancePatterns.detectArrayAppendWithoutCapacity(in: file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.code == "PERF-003" })
    }

    // MARK: - Array Contains Tests

    @Test("Detects array contains in loop")
    func arrayContainsInLoop() {
        let code = """
        for item in items {
            if array.contains(item) {
                process(item)
            }
        }
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let issues = PerformancePatterns.detectArrayContainsInLoop(in: file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.code == "PERF-007" })
    }

    // MARK: - Filter Count Tests

    @Test("Detects filter().count pattern")
    func filterCount() {
        let code = """
        if array.filter { $0.isValid }.count > 0 {
            print("has valid items")
        }
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let issues = PerformancePatterns.detectFilterCount(in: file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.code == "PERF-010" })
    }

    // MARK: - Performance Analyzer Integration Tests

    @Test("Full performance analysis detects multiple issues")
    func fullPerformanceAnalysis() async throws {
        let code = """
        func inefficientCode() {
            var result = ""
            for i in 0..<100 {
                for j in 0..<100 {
                    result += "value"
                }
            }

            var numbers: [Int] = []
            for n in 0..<1000 {
                numbers.append(n)
            }

            if items.filter { $0.isActive }.count > 0 {
                print("active")
            }
        }
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let analyzer = PerformanceAnalyzer()
        let result = try await analyzer.analyze(file)

        #expect(result.issues.count > 0)
        #expect(result.issues.allSatisfy { $0.category == .performance })
        #expect(result.score.performance < 100)
    }

    // MARK: - Metrics Calculator Tests

    @Test("Basic metrics calculation")
    func basicMetrics() {
        let code = """
        // This is a comment
        import Foundation

        func example() {
            let value = 1

            if value > 0 {
                print(value)
            }
        }

        /* Multi-line
           comment */
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let metrics = MetricsCalculator.calculate(for: file)

        #expect(metrics.linesOfCode > 0)
        #expect(metrics.commentLines > 0)
        #expect(metrics.blankLines > 0)
        #expect(metrics.cyclomaticComplexity > 0)
    }

    @Test("Complexity calculation with conditions")
    func complexityCalculation() {
        let code = """
        func complex(value: Int) -> String {
            if value > 0 {
                if value < 10 {
                    return "small"
                } else {
                    return "large"
                }
            } else {
                return "negative"
            }
        }
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let metrics = MetricsCalculator.calculate(for: file)

        #expect(metrics.cyclomaticComplexity > 1)
    }

    @Test("Maintainability index is within range")
    func maintainabilityIndex() {
        let code = """
        func simple() {
            let x = 1
            let y = 2
            print(x + y)
        }
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let metrics = MetricsCalculator.calculate(for: file)

        #expect(metrics.maintainabilityIndex > 0)
        #expect(metrics.maintainabilityIndex <= 100)
    }

    @Test("Duplication detection")
    func duplicationDetection() {
        let code = """
        func duplicate() {
            print("Hello")
            print("World")
            print("Hello")
            print("Hello")
        }
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let metrics = MetricsCalculator.calculate(for: file)

        #expect(metrics.duplicationPercentage > 0)
    }

    @Test("Metrics summary")
    func metricsSummary() {
        let code = """
        // Comment
        func test() {
            let x = 1
            print(x)
        }
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let metrics = MetricsCalculator.calculate(for: file)
        let summary = MetricsCalculator.summary(for: metrics)

        #expect(summary.totalLines > 0)
        #expect(summary.effectiveLOC > 0)
        #expect(!summary.summary.isEmpty)
    }

    @Test("Complexity ratings at thresholds")
    func complexityRatings() {
        #expect(CodeMetrics(cyclomaticComplexity: 3).complexityRating == "Simple")
        #expect(CodeMetrics(cyclomaticComplexity: 7).complexityRating == "Moderate")
        #expect(CodeMetrics(cyclomaticComplexity: 15).complexityRating == "Complex")
        #expect(CodeMetrics(cyclomaticComplexity: 25).complexityRating == "Very Complex")
    }

    @Test("Maintainability ratings at thresholds")
    func maintainabilityRatings() {
        #expect(CodeMetrics(maintainabilityIndex: 90).maintainabilityRating == "Excellent")
        #expect(CodeMetrics(maintainabilityIndex: 70).maintainabilityRating == "Good")
        #expect(CodeMetrics(maintainabilityIndex: 50).maintainabilityRating == "Moderate")
        #expect(CodeMetrics(maintainabilityIndex: 30).maintainabilityRating == "Poor")
    }

    @Test("Effective LOC calculation")
    func effectiveLOC() {
        let metrics = CodeMetrics(
            linesOfCode: 100,
            blankLines: 20,
            commentLines: 15
        )
        #expect(metrics.effectiveLinesOfCode == 65)
    }

    @Test("Comment ratio calculation")
    func commentRatio() {
        let code = """
        // Comment 1
        // Comment 2
        let x = 1
        let y = 2
        // Comment 3
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let metrics = MetricsCalculator.calculate(for: file)
        let summary = MetricsCalculator.summary(for: metrics)

        #expect(summary.commentRatio > 0)
        #expect(summary.commentRatio <= 100)
    }

    // MARK: - Complexity Analyzer Tests

    @Test("Detects high cyclomatic complexity in function")
    func cyclomaticComplexity() {
        let code = """
        func veryComplexFunction(value: Int) -> String {
            if value > 0 {
                if value < 10 {
                    if value == 5 {
                        return "five"
                    } else if value == 6 {
                        return "six"
                    } else {
                        return "small"
                    }
                } else if value < 100 {
                    if value == 50 {
                        return "fifty"
                    } else {
                        return "medium"
                    }
                } else {
                    if value == 500 {
                        return "fivehundred"
                    } else {
                        return "large"
                    }
                }
            } else {
                return "negative"
            }
        }
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let issues = ComplexityAnalyzer.analyzeCyclomaticComplexity(file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.category == .complexity })
    }

    @Test("Detects deep nesting")
    func deepNesting() {
        let code = """
        func deeplyNested() {
                        if true {
                                    if true {
                                                if true {
                                                            if true {
                                                                        let value = 1
                                                            }
                                                }
                                    }
                        }
        }
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let issues = ComplexityAnalyzer.analyzeNesting(file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.message.contains("Deep nesting") })
    }

    // MARK: - Code Smell Detector Tests

    @Test("Detects long method")
    func longMethod() {
        var longMethod = "func veryLongMethod() {\n"
        for i in 1...60 {
            longMethod += "    let value\(i) = \(i)\n"
        }
        longMethod += "}"

        let file = SourceFile(path: "test.swift", content: longMethod, language: .swift)
        let issues = CodeSmellDetector.detectLongMethods(file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.message.contains("Long method") })
    }

    @Test("Detects unused variable")
    func unusedVariable() {
        let code = """
        func example() {
            let unusedVar = 42
            let usedVar = 10
            print(usedVar)
        }
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let issues = CodeSmellDetector.detectUnusedVariables(file)

        #expect(issues.contains { $0.message.contains("unusedVar") })
    }

    @Test("Detects magic numbers")
    func magicNumbers() {
        let code = """
        func calculate() -> Int {
            return 42 * 365 + 1000
        }
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let issues = CodeSmellDetector.detectMagicNumbers(file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.message.contains("Magic number") })
    }

    @Test("Detects long parameter list")
    func longParameterList() {
        let code = """
        func tooManyParams(a: Int, b: String, c: Double, d: Bool, e: Float, f: Character) {
            print(a, b, c, d, e, f)
        }
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let issues = CodeSmellDetector.detectLongParameterLists(file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.message.contains("too many parameters") })
    }
}
