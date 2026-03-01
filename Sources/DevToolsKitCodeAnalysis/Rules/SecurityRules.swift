import Foundation

/// A security rule definition with CWE mapping.
///
/// > Since: 0.4.0
public struct SecurityRule: Sendable {
    /// Unique rule identifier (e.g. "SEC-001").
    public let id: String
    /// Regex pattern to match against source lines.
    public let pattern: String
    /// Severity level of violations.
    public let severity: Severity
    /// Human-readable description of the vulnerability.
    public let message: String
    /// Suggested remediation.
    public let recommendation: String
    /// Optional CWE identifier (e.g. "CWE-798").
    public let cwe: String?

    /// Create a security rule.
    public init(id: String, pattern: String, severity: Severity, message: String, recommendation: String, cwe: String? = nil) {
        self.id = id
        self.pattern = pattern
        self.severity = severity
        self.message = message
        self.recommendation = recommendation
        self.cwe = cwe
    }
}

/// Comprehensive database of built-in security rules.
///
/// Rules cover hardcoded secrets, SQL injection, command injection, path traversal,
/// insecure cryptography, unsafe deserialization, weak SSL/TLS, insecure data storage,
/// information disclosure, and insecure communication.
///
/// > Since: 0.4.0
public struct SecurityRules: Sendable {

    /// All built-in security rules.
    public static let allRules: [SecurityRule] = [
        // MARK: - Hardcoded Secrets (CWE-798)

        SecurityRule(
            id: "SEC-001",
            pattern: #"(?:password|passwd|pwd)\s*=\s*["'][^"']{3,}["']"#,
            severity: .error,
            message: "Hardcoded password detected",
            recommendation: "Never hardcode passwords. Use environment variables, secure key storage (Keychain), or configuration files that are not committed to version control.",
            cwe: "CWE-798"
        ),

        SecurityRule(
            id: "SEC-002",
            pattern: #"(?:api[_-]?key|apikey)\s*=\s*["'][^"']{10,}["']"#,
            severity: .error,
            message: "Hardcoded API key detected",
            recommendation: "Store API keys in secure locations like Keychain, environment variables, or use a secrets management service. Never commit keys to version control.",
            cwe: "CWE-798"
        ),

        SecurityRule(
            id: "SEC-003",
            pattern: #"(?:secret|token|auth)\s*=\s*["'][A-Za-z0-9+/=]{20,}["']"#,
            severity: .error,
            message: "Hardcoded secret or token detected",
            recommendation: "Use secure credential storage mechanisms. Never hardcode authentication tokens or secrets.",
            cwe: "CWE-798"
        ),

        SecurityRule(
            id: "SEC-004",
            pattern: #"private[_-]?key\s*=\s*["'][\s\S]{30,}["']"#,
            severity: .error,
            message: "Hardcoded private key detected",
            recommendation: "Private keys should never be hardcoded. Use secure key storage and certificate management.",
            cwe: "CWE-798"
        ),

        // MARK: - SQL Injection (CWE-89)

        SecurityRule(
            id: "SEC-005",
            pattern: #"\.execute\s*\([^)]*\+[^)]*\)"#,
            severity: .error,
            message: "Potential SQL injection vulnerability",
            recommendation: "Use parameterized queries or prepared statements instead of string concatenation. Never build SQL queries with user input directly.",
            cwe: "CWE-89"
        ),

        SecurityRule(
            id: "SEC-006",
            pattern: #"SELECT\s+.*\s+FROM\s+.*\s*\+\s*"#,
            severity: .error,
            message: "SQL query built with string concatenation",
            recommendation: "Use parameterized queries to prevent SQL injection attacks.",
            cwe: "CWE-89"
        ),

        // MARK: - Command Injection (CWE-78)

        SecurityRule(
            id: "SEC-007",
            pattern: #"Process\(\)\s*\.\s*launch\(\)"#,
            severity: .warning,
            message: "Direct process execution detected",
            recommendation: "Validate and sanitize all inputs before executing system commands. Use safe APIs and avoid shell execution when possible.",
            cwe: "CWE-78"
        ),

        SecurityRule(
            id: "SEC-008",
            pattern: #"system\s*\([^)]*\+[^)]*\)"#,
            severity: .error,
            message: "Command injection vulnerability",
            recommendation: "Never concatenate user input into system commands. Use safe APIs with parameter arrays instead of shell strings.",
            cwe: "CWE-78"
        ),

        // MARK: - Path Traversal (CWE-22)

        SecurityRule(
            id: "SEC-009",
            pattern: #"\.\./"#,
            severity: .warning,
            message: "Potential path traversal pattern detected",
            recommendation: "Validate and canonicalize file paths. Use safe path joining functions and check that resolved paths stay within intended boundaries.",
            cwe: "CWE-22"
        ),

        SecurityRule(
            id: "SEC-010",
            pattern: #"FileManager.*path.*\+.*input"#,
            severity: .warning,
            message: "File path constructed with user input",
            recommendation: "Validate file paths and ensure they remain within expected directories. Use path canonicalization and whitelist allowed paths.",
            cwe: "CWE-22"
        ),

        // MARK: - Insecure Crypto (CWE-327, CWE-328)

        SecurityRule(
            id: "SEC-011",
            pattern: #"\bMD5\b"#,
            severity: .error,
            message: "MD5 hash algorithm is cryptographically broken",
            recommendation: "Use SHA-256 or SHA-3 for hashing. MD5 is vulnerable to collision attacks and should never be used for security purposes.",
            cwe: "CWE-327"
        ),

        SecurityRule(
            id: "SEC-012",
            pattern: #"\bSHA1\b|\bSHA-1\b"#,
            severity: .warning,
            message: "SHA-1 hash algorithm is deprecated",
            recommendation: "Use SHA-256, SHA-384, or SHA-512 instead. SHA-1 is vulnerable to collision attacks.",
            cwe: "CWE-327"
        ),

        SecurityRule(
            id: "SEC-013",
            pattern: #"\bDES\b"#,
            severity: .error,
            message: "DES encryption is insecure",
            recommendation: "Use AES-256 for encryption. DES has a small key size and is vulnerable to brute force attacks.",
            cwe: "CWE-327"
        ),

        SecurityRule(
            id: "SEC-014",
            pattern: #"CCCrypt.*kCCAlgorithmRC4"#,
            severity: .error,
            message: "RC4 cipher is insecure",
            recommendation: "Use AES with a secure mode (GCM or CBC with HMAC). RC4 has known vulnerabilities.",
            cwe: "CWE-327"
        ),

        SecurityRule(
            id: "SEC-015",
            pattern: #"SecRandomCopyBytes.*arc4random"#,
            severity: .warning,
            message: "Using potentially weak random number generator",
            recommendation: "Use SecRandomCopyBytes for cryptographic operations. Avoid arc4random for security-sensitive randomness.",
            cwe: "CWE-338"
        ),

        // MARK: - Unsafe Deserialization (CWE-502)

        SecurityRule(
            id: "SEC-016",
            pattern: #"NSKeyedUnarchiver\.unarchiveObject"#,
            severity: .warning,
            message: "Potentially unsafe deserialization",
            recommendation: "Use unarchivedObject(ofClass:from:) with explicit class restrictions to prevent arbitrary object instantiation.",
            cwe: "CWE-502"
        ),

        // MARK: - Weak SSL/TLS (CWE-295)

        SecurityRule(
            id: "SEC-017",
            pattern: #"\.allowsAnyHTTPSCertificate"#,
            severity: .error,
            message: "Certificate validation disabled",
            recommendation: "Never disable certificate validation in production. This makes the app vulnerable to man-in-the-middle attacks.",
            cwe: "CWE-295"
        ),

        SecurityRule(
            id: "SEC-018",
            pattern: #"\.validatesDomainName\s*=\s*false"#,
            severity: .error,
            message: "Domain name validation disabled",
            recommendation: "Enable domain name validation to prevent man-in-the-middle attacks.",
            cwe: "CWE-295"
        ),

        // MARK: - Insecure Data Storage (CWE-312)

        SecurityRule(
            id: "SEC-019",
            pattern: #"UserDefaults.*password|UserDefaults.*token|UserDefaults.*secret"#,
            severity: .error,
            message: "Sensitive data stored in UserDefaults",
            recommendation: "Use Keychain to store sensitive data like passwords, tokens, and secrets. UserDefaults is not encrypted.",
            cwe: "CWE-312"
        ),

        SecurityRule(
            id: "SEC-020",
            pattern: #"FileManager.*write.*password|FileManager.*write.*token"#,
            severity: .warning,
            message: "Potentially storing sensitive data in plain text file",
            recommendation: "Encrypt sensitive data before writing to disk, or use Keychain for credentials.",
            cwe: "CWE-312"
        ),

        // MARK: - Information Disclosure (CWE-209, CWE-532)

        SecurityRule(
            id: "SEC-021",
            pattern: #"print.*error|print.*exception|print.*stacktrace"#,
            severity: .info,
            message: "Printing error details that may leak sensitive information",
            recommendation: "Avoid logging detailed error information in production. Use proper error handling and logging frameworks.",
            cwe: "CWE-532"
        ),

        SecurityRule(
            id: "SEC-022",
            pattern: #"NSLog.*password|NSLog.*token|NSLog.*secret"#,
            severity: .warning,
            message: "Logging sensitive information",
            recommendation: "Never log passwords, tokens, or other sensitive data. This information may be accessible to attackers.",
            cwe: "CWE-532"
        ),

        // MARK: - Weak Authentication (CWE-287)

        SecurityRule(
            id: "SEC-023",
            pattern: #"biometryType\s*==\s*\.none"#,
            severity: .info,
            message: "Biometric authentication not enforced",
            recommendation: "Consider requiring biometric or strong authentication for sensitive operations.",
            cwe: "CWE-287"
        ),

        // MARK: - Insecure Communication (CWE-319)

        SecurityRule(
            id: "SEC-024",
            pattern: #"http://(?!localhost|127\.0\.0\.1)"#,
            severity: .warning,
            message: "Insecure HTTP connection detected",
            recommendation: "Use HTTPS for all network communications to protect data in transit.",
            cwe: "CWE-319"
        ),

        SecurityRule(
            id: "SEC-025",
            pattern: #"App Transport Security.*NSAllowsArbitraryLoads.*true"#,
            severity: .error,
            message: "App Transport Security disabled",
            recommendation: "Enable ATS to enforce secure network connections. Only disable for specific domains if absolutely necessary.",
            cwe: "CWE-319"
        ),
    ]

    /// Filter rules by severity.
    /// - Parameter severity: The severity to filter by.
    /// - Returns: Rules matching the given severity.
    public static func rules(bySeverity severity: Severity) -> [SecurityRule] {
        allRules.filter { $0.severity == severity }
    }

    /// Filter rules by CWE identifier.
    /// - Parameter cwe: The CWE identifier to filter by (e.g. "CWE-798").
    /// - Returns: Rules matching the given CWE.
    public static func rules(byCWE cwe: String) -> [SecurityRule] {
        allRules.filter { $0.cwe == cwe }
    }

    /// Find a rule by its unique ID.
    /// - Parameter id: The rule ID (e.g. "SEC-001").
    /// - Returns: The matching rule, or nil if not found.
    public static func rule(byID id: String) -> SecurityRule? {
        allRules.first { $0.id == id }
    }
}
