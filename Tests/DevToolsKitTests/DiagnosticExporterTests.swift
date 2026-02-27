import Foundation
import Testing

@testable import DevToolsKit

@Suite(.serialized)
@MainActor
struct DiagnosticExporterTests {
    struct TestProvider: DiagnosticProvider {
        let sectionName: String
        let data: String

        func collect() async -> any Codable & Sendable {
            data
        }
    }

    @Test func diagnosticProviderRegistration() {
        let manager = DevToolsManager(keyPrefix: "test.\(UUID().uuidString)")

        manager.registerDiagnosticProvider(TestProvider(sectionName: "section-1", data: "data-1"))
        manager.registerDiagnosticProvider(TestProvider(sectionName: "section-2", data: "data-2"))

        #expect(manager.diagnosticProviders.count == 2)
        #expect(manager.diagnosticProviders[0].sectionName == "section-1")
        #expect(manager.diagnosticProviders[1].sectionName == "section-2")
    }

    @Test func diagnosticReportEncodesCorrectly() throws {
        let report = DiagnosticReport(
            appName: "TestApp",
            appVersion: "1.0.0",
            macOSVersion: "15.0",
            hardware: DiagnosticReport.HardwareInfo(
                model: "arm64",
                chipArchitecture: "arm64e",
                memoryGB: 16,
                processorCount: 10
            ),
            developerSettings: DiagnosticReport.DeveloperSettingsSnapshot(
                isDeveloperMode: true,
                logLevel: "debug"
            ),
            recentLogEntries: [
                DiagnosticReport.LogEntrySnapshot(
                    timestamp: Date(),
                    level: "info",
                    source: "test",
                    message: "Test log"
                )
            ],
            customSections: [
                "custom": AnyCodable("custom-data")
            ],
            timestamp: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(report)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("TestApp"))
        #expect(json.contains("1.0.0"))
        #expect(json.contains("arm64"))
        #expect(json.contains("Test log"))
    }
}
