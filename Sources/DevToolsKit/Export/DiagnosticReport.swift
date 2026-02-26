import Foundation

/// Complete diagnostic report structure.
public struct DiagnosticReport: Codable, Sendable {
    public let appName: String
    public let appVersion: String
    public let macOSVersion: String
    public let hardware: HardwareInfo
    public let developerSettings: DeveloperSettingsSnapshot
    public let recentLogEntries: [LogEntrySnapshot]
    public let customSections: [String: AnyCodable]
    public let timestamp: Date

    public struct HardwareInfo: Codable, Sendable {
        public let model: String
        public let chipArchitecture: String
        public let memoryGB: Int
        public let processorCount: Int

        public init(model: String, chipArchitecture: String, memoryGB: Int, processorCount: Int) {
            self.model = model
            self.chipArchitecture = chipArchitecture
            self.memoryGB = memoryGB
            self.processorCount = processorCount
        }
    }

    public struct DeveloperSettingsSnapshot: Codable, Sendable {
        public let isDeveloperMode: Bool
        public let logLevel: String

        public init(isDeveloperMode: Bool, logLevel: String) {
            self.isDeveloperMode = isDeveloperMode
            self.logLevel = logLevel
        }
    }

    public struct LogEntrySnapshot: Codable, Sendable {
        public let timestamp: Date
        public let level: String
        public let source: String
        public let message: String

        public init(timestamp: Date, level: String, source: String, message: String) {
            self.timestamp = timestamp
            self.level = level
            self.source = source
            self.message = message
        }
    }

    public init(
        appName: String,
        appVersion: String,
        macOSVersion: String,
        hardware: HardwareInfo,
        developerSettings: DeveloperSettingsSnapshot,
        recentLogEntries: [LogEntrySnapshot],
        customSections: [String: AnyCodable],
        timestamp: Date
    ) {
        self.appName = appName
        self.appVersion = appVersion
        self.macOSVersion = macOSVersion
        self.hardware = hardware
        self.developerSettings = developerSettings
        self.recentLogEntries = recentLogEntries
        self.customSections = customSections
        self.timestamp = timestamp
    }
}

/// Type-erased Codable wrapper for custom diagnostic sections.
public struct AnyCodable: Codable, Sendable {
    private let encodeClosure: @Sendable (Encoder) throws -> Void

    public init(_ value: some Codable & Sendable) {
        self.encodeClosure = { encoder in
            try value.encode(to: encoder)
        }
    }

    public func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }

    public init(from decoder: Decoder) throws {
        // Decode as a generic JSON value
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self.init(string)
        } else if let int = try? container.decode(Int.self) {
            self.init(int)
        } else if let double = try? container.decode(Double.self) {
            self.init(double)
        } else if let bool = try? container.decode(Bool.self) {
            self.init(bool)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.init(dict)
        } else if let array = try? container.decode([AnyCodable].self) {
            self.init(array)
        } else {
            self.init("")
        }
    }
}
