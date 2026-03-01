import Testing
import Foundation
@testable import DevToolsKitSecurity

@Suite("PermissionConfiguration")
struct PermissionConfigurationTests {

    @Test func defaultPermissionsHaveCorrectValues() {
        let defaults = PermissionConfiguration.defaultPermissions

        #expect(defaults.permission(for: "Read") == .allow)
        #expect(defaults.permission(for: "Glob") == .allow)
        #expect(defaults.permission(for: "grep") == .allow)
        #expect(defaults.permission(for: "Write") == .ask)
        #expect(defaults.permission(for: "Edit") == .ask)
        #expect(defaults.permission(for: "Bash") == .ask)
        #expect(defaults.permission(for: "SomeSkill") == .ask)
    }

    @Test func perOperationOverride() {
        var config = PermissionConfiguration.defaultPermissions
        config.perOperation["Read"] = .deny

        #expect(config.permission(for: "Read") == .deny)
        #expect(config.permission(for: "Glob") == .allow)
    }

    @Test func categoryFallback() {
        var config = PermissionConfiguration()
        config.perCategory[.read] = .allow
        config.perCategory[.write] = .deny

        #expect(config.permission(for: "Read") == .allow)
        #expect(config.permission(for: "Write") == .deny)
    }

    @Test func mergedConfigAppliesOverrides() {
        var base = PermissionConfiguration()
        base.perCategory[.read] = .allow
        base.perCategory[.write] = .ask
        base.perOperation["Read"] = .deny

        var override = PermissionConfiguration()
        override.perCategory[.write] = .deny
        override.perOperation["Write"] = .allow

        let merged = base.merged(with: override)

        #expect(merged.perCategory[.read] == .allow)
        #expect(merged.perCategory[.write] == .deny)
        #expect(merged.perOperation["Read"] == .deny)
        #expect(merged.perOperation["Write"] == .allow)
    }

    @Test func isCodable() throws {
        var config = PermissionConfiguration()
        config.perOperation["Read"] = .allow
        config.perCategory[.write] = .deny

        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(PermissionConfiguration.self, from: encoded)

        #expect(decoded.perOperation["Read"] == .allow)
        #expect(decoded.perCategory[.write] == .deny)
    }

    @Test func emptyOverridePreservesConfig() {
        var appConfig = PermissionConfiguration()
        appConfig.perOperation["Read"] = .allow
        appConfig.perCategory[.write] = .ask

        let emptyOverride = PermissionConfiguration()
        let merged = appConfig.merged(with: emptyOverride)

        #expect(merged.permission(for: "Read") == .allow)
        #expect(merged.permission(for: "Write") == .ask)
    }

    @Test func projectOverrideWins() {
        var appConfig = PermissionConfiguration()
        appConfig.perOperation["Read"] = .allow
        appConfig.perOperation["Write"] = .ask
        appConfig.perOperation["Bash"] = .ask

        var projectOverride = PermissionConfiguration()
        projectOverride.perOperation["Write"] = .deny
        projectOverride.perOperation["Bash"] = .allow

        let merged = appConfig.merged(with: projectOverride)

        #expect(merged.permission(for: "Read") == .allow)
        #expect(merged.permission(for: "Write") == .deny)
        #expect(merged.permission(for: "Bash") == .allow)
    }
}

@Suite("OperationCategory")
struct OperationCategoryTests {

    @Test func defaultMappingHandlesAllKnownOperations() {
        #expect(OperationCategory.category(for: "Read") == .read)
        #expect(OperationCategory.category(for: "Glob") == .read)
        #expect(OperationCategory.category(for: "grep") == .read)
        #expect(OperationCategory.category(for: "Write") == .write)
        #expect(OperationCategory.category(for: "Edit") == .write)
        #expect(OperationCategory.category(for: "Bash") == .execute)
        #expect(OperationCategory.category(for: "MySkill") == .skill)
    }

    @Test func caseInsensitiveMapping() {
        #expect(OperationCategory.category(for: "GREP") == .read)
        #expect(OperationCategory.category(for: "GrEp") == .read)
        #expect(OperationCategory.category(for: "bash") == .execute)
    }

    @Test func customMapping() {
        let custom: [String: OperationCategory] = [
            "fetch": .read,
            "deploy": .execute,
        ]
        #expect(OperationCategory.category(for: "fetch", using: custom) == .read)
        #expect(OperationCategory.category(for: "deploy", using: custom) == .execute)
        #expect(OperationCategory.category(for: "unknown", using: custom) == .skill)
    }

    @Test func isCodable() throws {
        let category: OperationCategory = .read
        let encoded = try JSONEncoder().encode(category)
        let decoded = try JSONDecoder().decode(OperationCategory.self, from: encoded)
        #expect(decoded == .read)
    }
}

@Suite("PermissionLevel")
struct PermissionLevelTests {

    @Test func isCodable() throws {
        let level: PermissionLevel = .ask
        let encoded = try JSONEncoder().encode(level)
        let decoded = try JSONDecoder().decode(PermissionLevel.self, from: encoded)
        #expect(decoded == .ask)
    }
}

@Suite("PermissionResponse")
struct PermissionResponseTests {

    @Test func equality() {
        #expect(PermissionResponse.allow == .allow)
        #expect(PermissionResponse.deny == .deny)
        #expect(PermissionResponse.allowForSession == .allowForSession)
        #expect(PermissionResponse.allow != .deny)
    }

    @Test func isCodable() throws {
        let response: PermissionResponse = .allowForSession
        let encoded = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(PermissionResponse.self, from: encoded)
        #expect(decoded == .allowForSession)
    }
}

@Suite("RiskLevel")
struct RiskLevelTests {

    @Test func isCodable() throws {
        let risk: RiskLevel = .high
        let encoded = try JSONEncoder().encode(risk)
        let decoded = try JSONDecoder().decode(RiskLevel.self, from: encoded)
        #expect(decoded == .high)
    }
}

@Suite("PermissionSource")
struct PermissionSourceTests {

    @Test func isCodable() throws {
        let source: PermissionSource = .projectOverride
        let encoded = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(PermissionSource.self, from: encoded)
        #expect(decoded == .projectOverride)
    }
}

@Suite("AutoApprovePermissionHandler")
struct AutoApprovePermissionHandlerTests {

    @Test func alwaysAllows() async {
        let handler = AutoApprovePermissionHandler()
        let request = PermissionRequest(
            operationName: "Write",
            operationCategory: .write,
            arguments: ["file": "test.txt"],
            riskLevel: .medium
        )
        let response = await handler.requestPermission(request)
        #expect(response == .allow)
    }
}
