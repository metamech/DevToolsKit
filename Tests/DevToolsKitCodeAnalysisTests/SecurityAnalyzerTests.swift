import Foundation
import Testing
@testable import DevToolsKitCodeAnalysis

@Suite("Security Analyzer")
struct SecurityAnalyzerTests {

    // MARK: - Hardcoded Secrets Tests

    @Test("Detects hardcoded password")
    func hardcodedPassword() {
        let code = """
        let password = "MySecretPassword123"
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let rules = SecurityRules.allRules.filter { $0.id == "SEC-001" }
        let issues = SecurityPatterns.findMatches(for: rules, in: file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.code == "SEC-001" && $0.cwe == "CWE-798" })
    }

    @Test("Detects hardcoded API key")
    func hardcodedAPIKey() {
        let code = """
        let api_key = "sk_live_1234567890abcdefghij"
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let rules = SecurityRules.allRules.filter { $0.id == "SEC-002" }
        let issues = SecurityPatterns.findMatches(for: rules, in: file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.code == "SEC-002" && $0.cwe == "CWE-798" })
    }

    @Test("Detects hardcoded token")
    func hardcodedToken() {
        let code = """
        let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let rules = SecurityRules.allRules.filter { $0.id == "SEC-003" }
        let issues = SecurityPatterns.findMatches(for: rules, in: file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.code == "SEC-003" })
    }

    // MARK: - SQL Injection Tests

    @Test("Detects SQL injection with execute")
    func sqlInjectionWithExecute() {
        let code = """
        database.execute("SELECT * FROM users WHERE id = " + userInput)
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let rules = SecurityRules.allRules.filter { $0.id == "SEC-005" }
        let issues = SecurityPatterns.findMatches(for: rules, in: file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.code == "SEC-005" && $0.cwe == "CWE-89" })
    }

    @Test("Detects SQL query built with string concatenation")
    func sqlInjectionWithQuery() {
        let code = """
        let query = "SELECT * FROM users WHERE name = '" + userInput + "'"
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let rules = SecurityRules.allRules.filter { $0.id == "SEC-006" }
        let issues = SecurityPatterns.findMatches(for: rules, in: file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.code == "SEC-006" && $0.cwe == "CWE-89" })
    }

    // MARK: - Command Injection Tests

    @Test("Detects process launch")
    func processLaunch() {
        let code = "Process().launch()"

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let rules = SecurityRules.allRules.filter { $0.id == "SEC-007" }
        let issues = SecurityPatterns.findMatches(for: rules, in: file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.code == "SEC-007" && $0.cwe == "CWE-78" })
    }

    // MARK: - Path Traversal Tests

    @Test("Detects path traversal pattern")
    func pathTraversal() {
        let code = """
        let path = "../../../etc/passwd"
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let rules = SecurityRules.allRules.filter { $0.id == "SEC-009" }
        let issues = SecurityPatterns.findMatches(for: rules, in: file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.code == "SEC-009" && $0.cwe == "CWE-22" })
    }

    // MARK: - Insecure Crypto Tests

    @Test("Detects MD5 usage")
    func md5Usage() {
        let code = """
        let hash = MD5(data)
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let rules = SecurityRules.allRules.filter { $0.id == "SEC-011" }
        let issues = SecurityPatterns.findMatches(for: rules, in: file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.code == "SEC-011" && $0.cwe == "CWE-327" })
        #expect(issues.first?.severity == .error)
    }

    @Test("Detects SHA-1 usage")
    func sha1Usage() {
        let code = """
        let hash = SHA1(data)
        let hash2 = SHA-1(data)
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let rules = SecurityRules.allRules.filter { $0.id == "SEC-012" }
        let issues = SecurityPatterns.findMatches(for: rules, in: file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.code == "SEC-012" && $0.cwe == "CWE-327" })
        #expect(issues.first?.severity == .warning)
    }

    @Test("Detects DES usage")
    func desUsage() {
        let code = """
        let encrypted = DES.encrypt(data)
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let rules = SecurityRules.allRules.filter { $0.id == "SEC-013" }
        let issues = SecurityPatterns.findMatches(for: rules, in: file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.code == "SEC-013" })
    }

    // MARK: - Insecure Data Storage Tests

    @Test("Detects sensitive data in UserDefaults")
    func userDefaultsPassword() {
        let code = """
        UserDefaults.standard.set("mypassword", forKey: "password")
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let rules = SecurityRules.allRules.filter { $0.id == "SEC-019" }
        let issues = SecurityPatterns.findMatches(for: rules, in: file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.code == "SEC-019" && $0.cwe == "CWE-312" })
    }

    // MARK: - Information Disclosure Tests

    @Test("Detects print with error details")
    func printError() {
        let code = """
        print("Error: \\(error)")
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let rules = SecurityRules.allRules.filter { $0.id == "SEC-021" }
        let issues = SecurityPatterns.findMatches(for: rules, in: file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.code == "SEC-021" && $0.cwe == "CWE-532" })
    }

    @Test("Detects NSLog with sensitive data")
    func nsLogSensitive() {
        let code = """
        NSLog("Password: %@", password)
        NSLog("Token: %@", token)
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let rules = SecurityRules.allRules.filter { $0.id == "SEC-022" }
        let issues = SecurityPatterns.findMatches(for: rules, in: file)

        #expect(issues.count == 2)
        #expect(issues.allSatisfy { $0.code == "SEC-022" && $0.cwe == "CWE-532" })
    }

    // MARK: - Insecure Communication Tests

    @Test("Detects insecure HTTP connection")
    func httpConnection() {
        let code = """
        let url = URL(string: "http://api.example.com/data")
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let rules = SecurityRules.allRules.filter { $0.id == "SEC-024" }
        let issues = SecurityPatterns.findMatches(for: rules, in: file)

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.code == "SEC-024" && $0.cwe == "CWE-319" })
    }

    @Test("Allows HTTP localhost connections")
    func httpLocalhostAllowed() {
        let code = """
        let url = URL(string: "http://localhost:8080")
        let url2 = URL(string: "http://127.0.0.1:8080")
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let rules = SecurityRules.allRules.filter { $0.id == "SEC-024" }
        let issues = SecurityPatterns.findMatches(for: rules, in: file)

        #expect(issues.isEmpty)
    }

    // MARK: - Contextual Vulnerabilities Tests

    @Test("Detects eval/exec code injection")
    func evalCodeInjection() {
        let code = """
        eval(userCode)
        exec(command)
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let issues = SecurityPatterns.findContextualVulnerabilities(in: file)

        let evalIssues = issues.filter { $0.code == "SEC-026" }
        #expect(evalIssues.count == 2)
        #expect(evalIssues.allSatisfy { $0.cwe == "CWE-95" })
    }

    @Test("Detects unvalidated redirect")
    func unvalidatedRedirect() {
        let code = """
        redirect(to: request.url)
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let issues = SecurityPatterns.findContextualVulnerabilities(in: file)

        let redirectIssues = issues.filter { $0.code == "SEC-027" }
        #expect(!redirectIssues.isEmpty)
        #expect(redirectIssues.contains { $0.cwe == "CWE-601" })
    }

    @Test("Detects weak random in security context")
    func weakRandomInSecurityContext() {
        let code = """
        let sessionKey = arc4random()
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let issues = SecurityPatterns.findContextualVulnerabilities(in: file)

        let randomIssues = issues.filter { $0.code == "SEC-028" }
        #expect(!randomIssues.isEmpty)
        #expect(randomIssues.contains { $0.cwe == "CWE-338" })
    }

    // MARK: - Integration Tests

    @Test("Full security analysis detects multiple issues")
    func fullSecurityAnalysis() async throws {
        let vulnerableCode = """
        let password = "hardcoded123"
        let apiKey = "sk_live_abcdefghijklmnop"

        func query(user: String) {
            let sql = "SELECT * FROM users WHERE name = '" + user + "'"
            let hash = MD5(sql)
        }

        func log() {
            NSLog("Password: %@", password)
        }
        """

        let file = SourceFile(path: "test.swift", content: vulnerableCode, language: .swift)
        let analyzer = SecurityAnalyzer()
        let result = try await analyzer.analyze(file)

        #expect(result.issues.count > 0)
        #expect(result.issues.allSatisfy { $0.category == .security })

        let errors = result.issues.filter { $0.severity == .error }
        #expect(errors.count > 0)
        #expect(result.score.security < 100)
    }

    @Test("Security summary aggregation")
    func securitySummary() async throws {
        let code = """
        let password = "test123"
        let apiKey = "sk_live_1234567890abcdef"
        let hash = MD5(data)
        """

        let file = SourceFile(path: "test.swift", content: code, language: .swift)
        let analyzer = SecurityAnalyzer()
        let result = try await analyzer.analyze(file)

        let summary = SecurityAnalyzer.securitySummary(from: result)

        #expect(summary.totalIssues > 0)
        #expect(summary.hasCriticalIssues)
        #expect(!summary.cweBreakdown.isEmpty)
        #expect(summary.securityScore < 100)
    }

    @Test("Batch security analysis processes multiple files")
    func batchSecurityAnalysis() async throws {
        let file1 = SourceFile(
            path: "file1.swift",
            content: "let password = \"test123\"",
            language: .swift
        )

        let file2 = SourceFile(
            path: "file2.swift",
            content: "let hash = MD5(data)",
            language: .swift
        )

        let batchResult = try await SecurityAnalyzer.analyzeBatch([file1, file2])

        #expect(batchResult.results.count == 2)
        #expect(batchResult.totalIssues > 0)
    }

    @Test("Clean code produces no security issues")
    func cleanCodeNoIssues() async throws {
        let cleanCode = """
        import Foundation

        func secureHash(data: Data) -> Data {
            return SHA256.hash(data: data)
        }

        func storePassword(_ password: String) {
            // Store in Keychain, not UserDefaults
            KeychainHelper.save(password, forKey: "user_password")
        }
        """

        let file = SourceFile(path: "test.swift", content: cleanCode, language: .swift)
        let analyzer = SecurityAnalyzer()
        let result = try await analyzer.analyze(file)

        #expect(result.issues.count == 0)
        #expect(result.score.security == 100)
    }
}
