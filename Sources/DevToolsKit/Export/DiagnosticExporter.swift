import Foundation
import AppKit

/// Collects diagnostic data from all registered providers and exports as JSON.
@MainActor
public struct DiagnosticExporter {
    private let manager: DevToolsManager
    private let logStore: DevToolsLogStore?
    private let appName: String

    public init(
        manager: DevToolsManager,
        logStore: DevToolsLogStore? = nil,
        appName: String? = nil
    ) {
        self.manager = manager
        self.logStore = logStore
        self.appName = appName
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "app"
    }

    /// Export diagnostics: collect all data, present save panel, write JSON.
    public func export() async {
        let report = await collectReport()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(report),
              let json = String(data: data, encoding: .utf8) else {
            showError("Failed to serialize diagnostic report.")
            return
        }

        let dateString = ISO8601DateFormatter().string(from: Date())
        let sanitizedAppName = appName.lowercased().replacingOccurrences(of: " ", with: "-")
        let filename = "\(sanitizedAppName)-diagnostics-\(dateString).json"

        let savePanel = NSSavePanel()
        savePanel.title = "Export Diagnostics"
        savePanel.nameFieldStringValue = filename
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true

        let response = await savePanel.begin()
        guard response == .OK, let url = savePanel.url else { return }

        do {
            try json.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            showError("Failed to save diagnostic report: \(error.localizedDescription)")
        }
    }

    private func collectReport() async -> DiagnosticReport {
        var customSections: [String: AnyCodable] = [:]

        for provider in manager.diagnosticProviders {
            let data = await provider.collect()
            customSections[provider.sectionName] = AnyCodable(AnyEncodableWrapper(data))
        }

        return DiagnosticReport(
            appName: appName,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            hardware: collectHardware(),
            developerSettings: DiagnosticReport.DeveloperSettingsSnapshot(
                isDeveloperMode: manager.isDeveloperMode,
                logLevel: manager.logLevel.rawValue
            ),
            recentLogEntries: collectRecentLogs(),
            customSections: customSections,
            timestamp: Date()
        )
    }

    private func collectHardware() -> DiagnosticReport.HardwareInfo {
        var sysinfo = utsname()
        uname(&sysinfo)
        let model = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0) ?? "unknown"
            }
        }

        let memoryBytes = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Int(memoryBytes / 1_073_741_824)

        return DiagnosticReport.HardwareInfo(
            model: model,
            chipArchitecture: machineHardwareName() ?? "unknown",
            memoryGB: memoryGB,
            processorCount: ProcessInfo.processInfo.processorCount
        )
    }

    private func machineHardwareName() -> String? {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return machine.withUnsafeBytes { rawPtr in
            String(decoding: rawPtr.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }

    private func collectRecentLogs() -> [DiagnosticReport.LogEntrySnapshot] {
        guard let logStore else { return [] }
        return logStore.recentEntries(100).map { entry in
            DiagnosticReport.LogEntrySnapshot(
                timestamp: entry.timestamp,
                level: entry.level.rawValue,
                source: entry.source,
                message: entry.message
            )
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

/// Wrapper to type-erase Codable for encoding.
private struct AnyEncodableWrapper: Codable, Sendable {
    private let encodeClosure: @Sendable (Encoder) throws -> Void

    init(_ value: any Codable & Sendable) {
        self.encodeClosure = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }

    init(from decoder: Decoder) throws {
        self.encodeClosure = { _ in }
    }
}
