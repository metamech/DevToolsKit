import Testing
import Foundation
@testable import DevToolsKitSecurity

@Suite("CommandPolicy")
struct CommandPolicyTests {

    @Test func deniesDangerousCommands() {
        let policy = CommandPolicy.default

        let dangerousCommands = [
            "rm -rf /",
            "sudo apt-get install",
            ":(){ :|: & };:",
            "mkfs /dev/sda1",
            "dd if=/dev/zero of=/dev/sda",
        ]

        for command in dangerousCommands {
            let result = policy.isDenied(command)
            #expect(result.denied, "Command should be denied: \(command)")
            #expect(result.reason != nil)
        }
    }

    @Test func allowsSafeCommands() {
        let policy = CommandPolicy.default

        let safeCommands = [
            "ls -la",
            "git status",
            "swift build",
            "cat README.md",
            "echo 'hello world'",
        ]

        for command in safeCommands {
            let result = policy.isDenied(command)
            #expect(!result.denied, "Command should be allowed: \(command)")
            #expect(result.reason == nil)
        }
    }

    @Test func customPolicy() {
        let policy = CommandPolicy(deniedPatterns: [#"rm\s+"#])

        let result1 = policy.isDenied("rm file.txt")
        #expect(result1.denied)

        let result2 = policy.isDenied("ls -la")
        #expect(!result2.denied)
    }

    @Test func isCodable() throws {
        let policy = CommandPolicy(deniedPatterns: ["test"])
        let encoded = try JSONEncoder().encode(policy)
        let decoded = try JSONDecoder().decode(CommandPolicy.self, from: encoded)
        #expect(decoded.deniedPatterns == ["test"])
    }
}
