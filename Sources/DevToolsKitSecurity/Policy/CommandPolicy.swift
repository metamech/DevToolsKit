import Foundation

/// Security policy for command execution.
///
/// Evaluates commands against a set of deny patterns to prevent
/// execution of dangerous operations.
///
/// Since 0.4.0
public struct CommandPolicy: Codable, Sendable {
    /// Regex patterns for denied commands.
    public let deniedPatterns: [String]

    /// Creates a command policy with the given deny patterns.
    /// - Parameter deniedPatterns: Array of regex patterns for denied commands.
    public init(deniedPatterns: [String]) {
        self.deniedPatterns = deniedPatterns
    }

    /// Check if a command is denied by security policy.
    /// - Parameter command: The command to check.
    /// - Returns: A tuple indicating if denied and the reason.
    public func isDenied(_ command: String) -> (denied: Bool, reason: String?) {
        for pattern in deniedPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                continue
            }

            let range = NSRange(command.startIndex..., in: command)
            if regex.firstMatch(in: command, options: [], range: range) != nil {
                return (true, "Command matches security deny pattern: \(pattern)")
            }
        }

        return (false, nil)
    }

    /// Default security policy with common dangerous command patterns.
    public static let `default` = CommandPolicy(deniedPatterns: [
        // Dangerous file operations
        #"rm\s+-rf\s+/"#,
        #"rm\s+-fr\s+/"#,
        #"rm\s+--recursive\s+--force\s+/"#,
        #"rm\s+-rf\s+\*"#,
        #"rm\s+-fr\s+\*"#,

        // Privilege escalation
        #"^\s*sudo\s+"#,
        #"^\s*su\s+"#,

        // Fork bombs
        #":\(\)\{.*:\|:.*\}.*;"#,
        #"\.\/\.\/\.\/\.\/"#,

        // Dangerous system operations
        #"mkfs"#,
        #"dd\s+if=/dev/zero"#,
        #":\(\)\{.*\}.*\&"#,

        // Network-based attacks
        #"while\s*:\s*;\s*do.*curl"#,
        #"while\s*true\s*;\s*do.*wget"#,

        // Kernel operations
        #"echo\s+.*>\s*/proc/"#,
        #"echo\s+.*>\s*/sys/"#,
    ])
}
