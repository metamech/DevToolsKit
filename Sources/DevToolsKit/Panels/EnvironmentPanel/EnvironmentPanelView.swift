import SwiftUI

/// Displays system and app environment information.
public struct EnvironmentPanelView: View {
    @State private var systemInfo: [(String, String)] = []

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Environment")
                    .font(.headline)
                Spacer()
                Button("Refresh") { loadInfo() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button {
                    let text = systemInfo.map { "\($0.0): \($0.1)" }.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copy to clipboard")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if systemInfo.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(systemInfo, id: \.0) { key, value in
                    HStack {
                        Text(key)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 180, alignment: .trailing)
                        Text(value)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .listRowSeparator(.visible)
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear { loadInfo() }
    }

    private func loadInfo() {
        let processInfo = ProcessInfo.processInfo
        let osVersion = processInfo.operatingSystemVersion

        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0) ?? "unknown"
            }
        }

        let memoryBytes = processInfo.physicalMemory
        let memoryGB = Double(memoryBytes) / 1_073_741_824

        let thermalState: String = switch processInfo.thermalState {
        case .nominal: "Nominal"
        case .fair: "Fair"
        case .serious: "Serious"
        case .critical: "Critical"
        @unknown default: "Unknown"
        }

        let currentMemoryMB = Double(getProcessMemory()) / 1_048_576

        systemInfo = [
            ("macOS Version", "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"),
            ("Hardware Model", machine),
            ("Physical Memory", String(format: "%.1f GB", memoryGB)),
            ("Processor Count", "\(processInfo.processorCount) cores"),
            ("Active Processor Count", "\(processInfo.activeProcessorCount) cores"),
            ("Thermal State", thermalState),
            ("App Version", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"),
            ("Build Number", Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"),
            ("Bundle ID", Bundle.main.bundleIdentifier ?? "unknown"),
            ("Process Memory", String(format: "%.1f MB", currentMemoryMB)),
            ("System Uptime", formatUptime(processInfo.systemUptime)),
            ("Low Power Mode", processInfo.isLowPowerModeEnabled ? "Yes" : "No"),
        ]
    }

    private func getProcessMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.resident_size : 0
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}
