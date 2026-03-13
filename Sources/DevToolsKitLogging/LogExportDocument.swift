import SwiftUI
import UniformTypeIdentifiers

/// Export format for log entries.
///
/// Since 0.6.0
public enum LogExportFormat: Sendable {
    /// Plain text, one entry per line.
    case plainText
    /// Pretty-printed JSON array.
    case json
}

/// A `FileDocument` wrapping formatted log entries for use with `.fileExporter()`.
///
/// Since 0.6.0
public struct LogExportDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.plainText, .json] }

    private let content: String
    private let format: LogExportFormat

    /// Create an export document from log entries.
    ///
    /// - Parameters:
    ///   - entries: The log entries to export.
    ///   - format: The export format.
    public init(entries: [DevToolsLogEntry], format: LogExportFormat) {
        self.format = format
        switch format {
        case .plainText:
            self.content = LogEntryFormatter.formatText(entries)
        case .json:
            self.content = (try? LogEntryFormatter.formatJSON(entries)) ?? "[]"
        }
    }

    public init(configuration: ReadConfiguration) throws {
        self.format = .plainText
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.content = String(decoding: data, as: UTF8.self)
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = content.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return FileWrapper(regularFileWithContents: data)
    }

    /// The UTType for this document's format.
    public var contentType: UTType {
        switch format {
        case .plainText: .plainText
        case .json: .json
        }
    }
}
