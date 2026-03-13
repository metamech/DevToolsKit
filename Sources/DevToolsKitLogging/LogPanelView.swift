#if canImport(AppKit)
import AppKit
#endif
import DevToolsKit
import SwiftUI
import UniformTypeIdentifiers

/// Log viewer UI showing aggregated, filterable log entries with resizable columns.
public struct LogPanelView: View {
    @Bindable var logStore: DevToolsLogStore
    @State private var autoScroll = true
    @State private var timestampWidth: CGFloat
    @State private var levelWidth: CGFloat
    @State private var sourceWidth: CGFloat
    @State private var isExporting = false
    @State private var exportDocument: LogExportDocument?
    @State private var exportContentType: UTType = .plainText
    @State private var copyBounce: Int = 0

    private let keyPrefix: String

    private static let defaultTimestampWidth: CGFloat = 85
    private static let defaultLevelWidth: CGFloat = 50
    private static let defaultSourceWidth: CGFloat = 160

    /// - Parameters:
    ///   - logStore: The shared log store to display entries from.
    ///   - keyPrefix: UserDefaults key prefix for persisting column widths; defaults to `"devtools"`.
    public init(logStore: DevToolsLogStore, keyPrefix: String = "devtools") {
        self.logStore = logStore
        self.keyPrefix = keyPrefix

        let defaults = UserDefaults.standard
        let tw = defaults.double(forKey: "\(keyPrefix).logColumn.timestamp")
        let lw = defaults.double(forKey: "\(keyPrefix).logColumn.level")
        let sw = defaults.double(forKey: "\(keyPrefix).logColumn.source")

        _timestampWidth = State(initialValue: tw > 0 ? tw : Self.defaultTimestampWidth)
        _levelWidth = State(initialValue: lw > 0 ? lw : Self.defaultLevelWidth)
        _sourceWidth = State(initialValue: sw > 0 ? sw : Self.defaultSourceWidth)
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            columnHeader
            Divider()

            if logStore.filteredEntries.isEmpty {
                ContentUnavailableView(
                    "No Log Entries",
                    systemImage: "doc.text",
                    description: Text("Log entries will appear here when the app generates output.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(logStore.filteredEntries) { entry in
                        LogEntryRow(
                            entry: entry,
                            timestampWidth: timestampWidth,
                            levelWidth: levelWidth,
                            sourceWidth: sourceWidth
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                        .id(entry.id)
                        #if !os(tvOS) && !os(watchOS)
                        .contextMenu {
                            Button {
                                LogEntryFormatter.copyToClipboard(entry.message)
                            } label: {
                                Label("Copy Message", systemImage: "doc.on.clipboard")
                            }
                            Button {
                                LogEntryFormatter.copyToClipboard(
                                    LogEntryFormatter.formatLine(entry)
                                )
                            } label: {
                                Label("Copy Entry", systemImage: "list.clipboard")
                            }
                        }
                        #endif
                    }
                    .listStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .onChange(of: logStore.filteredEntries.last?.id) { _, newID in
                        if autoScroll, let newID {
                            proxy.scrollTo(newID, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: exportContentType,
            defaultFilename: "logs"
        ) { _ in }
        .onChange(of: timestampWidth) { _, value in
            UserDefaults.standard.set(value, forKey: "\(keyPrefix).logColumn.timestamp")
        }
        .onChange(of: levelWidth) { _, value in
            UserDefaults.standard.set(value, forKey: "\(keyPrefix).logColumn.level")
        }
        .onChange(of: sourceWidth) { _, value in
            UserDefaults.standard.set(value, forKey: "\(keyPrefix).logColumn.source")
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            Text("Time")
                .frame(width: timestampWidth, alignment: .leading)
            ColumnDivider(width: $timestampWidth, minWidth: 60)

            Text("Level")
                .frame(width: levelWidth, alignment: .leading)
            ColumnDivider(width: $levelWidth, minWidth: 36)

            Text("Source")
                .frame(width: sourceWidth, alignment: .leading)
            ColumnDivider(width: $sourceWidth, minWidth: 60)

            Text("Message")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(.caption2, design: .monospaced, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("Level", selection: $logStore.filterLevel) {
                Text("All").tag(DevToolsLogLevel.trace)
                Text("Debug").tag(DevToolsLogLevel.debug)
                Text("Info").tag(DevToolsLogLevel.info)
                Text("Warning").tag(DevToolsLogLevel.warning)
                Text("Error").tag(DevToolsLogLevel.error)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 380)

            Picker("Source", selection: $logStore.filterSource) {
                Text("All").tag(String?.none)
                ForEach(logStore.knownSources, id: \.self) { source in
                    Text(source).tag(String?.some(source))
                }
            }
            .frame(width: 120)

            TextField("Search...", text: $logStore.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)

            Spacer()

            Text("\(logStore.filteredEntries.count) entries")
                .font(.caption)
                .foregroundStyle(.secondary)

            #if !os(tvOS) && !os(watchOS)
            Divider()
                .frame(height: 16)

            Button {
                let text = LogEntryFormatter.formatText(logStore.filteredEntries)
                LogEntryFormatter.copyToClipboard(text)
                copyBounce += 1
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .symbolEffect(.bounce, value: copyBounce)
            }
            .disabled(logStore.filteredEntries.isEmpty)
            .help(logStore.filteredEntries.isEmpty
                ? "No entries to copy"
                : "Copy filtered entries to clipboard")
            .accessibilityLabel("Copy all filtered entries to clipboard")
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Menu {
                Button("Export as Text...") {
                    exportDocument = LogExportDocument(
                        entries: logStore.filteredEntries, format: .plainText
                    )
                    exportContentType = .plainText
                    isExporting = true
                }
                Button("Export as JSON...") {
                    exportDocument = LogExportDocument(
                        entries: logStore.filteredEntries, format: .json
                    )
                    exportContentType = .json
                    isExporting = true
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .disabled(logStore.filteredEntries.isEmpty)
            #if os(macOS)
            .menuStyle(.borderlessButton)
            #endif
            .help(logStore.filteredEntries.isEmpty
                ? "No entries to export"
                : "Export log entries")
            .accessibilityLabel("Export log entries")

            Divider()
                .frame(height: 16)
            #endif

            Toggle("Auto-scroll", isOn: $autoScroll)
                #if os(macOS)
                .toggleStyle(.checkbox)
                #endif
                .font(.caption)

            Button(action: { logStore.clear() }) {
                Image(systemName: "trash")
            }
            .help("Clear all log entries")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Column Divider

/// Draggable divider handle for resizing log columns.
private struct ColumnDivider: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    @State private var startWidth: CGFloat = 0
    @State private var isDragging: Bool = false

    var body: some View {
        Rectangle()
            .fill(isDragging ? Color.accentColor : Color.gray.opacity(0.3))
            .frame(width: 4, height: 14)
            .contentShape(Rectangle().inset(by: -4))
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if !isDragging {
                            startWidth = width
                            isDragging = true
                        }
                        width = max(minWidth, startWidth + value.translation.width)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            #if canImport(AppKit)
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            #endif
            .padding(.horizontal, 2)
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let entry: DevToolsLogEntry
    let timestampWidth: CGFloat
    let levelWidth: CGFloat
    let sourceWidth: CGFloat

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(Self.timeFormatter.string(from: entry.timestamp))
                .foregroundStyle(.secondary)
                .frame(width: timestampWidth, alignment: .leading)

            Text(levelText)
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(levelColor, in: RoundedRectangle(cornerRadius: 3))
                .frame(width: levelWidth)

            Text(truncateReverseDNS(entry.source, fitting: sourceWidth))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: sourceWidth, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.head)
                .help(entry.source)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.message)
                    .textSelection(.enabled)
                    .lineLimit(nil)

                if let metadata = entry.metadata {
                    Text(metadata)
                        .foregroundStyle(.tertiary)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var levelText: String {
        switch entry.level {
        case .trace: "TRC"
        case .debug: "DBG"
        case .info: "INF"
        case .warning: "WRN"
        case .error: "ERR"
        }
    }

    private var levelColor: Color {
        switch entry.level {
        case .trace: .purple
        case .debug: .gray
        case .info: .blue
        case .warning: .orange
        case .error: .red
        }
    }
}

// MARK: - Reverse-DNS Truncation

/// Truncate a reverse-DNS source string to fit within a given width.
///
/// Removes leading dot-separated components until the text fits, preserving
/// at least the last two components. Single-component strings are returned as-is.
///
/// - Parameters:
///   - source: The full source string (e.g., `"com.metamech.maccad.canvas.view"`).
///   - width: The available width in points.
/// - Returns: The truncated source (e.g., `"maccad.canvas.view"`).
func truncateReverseDNS(_ source: String, fitting width: CGFloat) -> String {
    #if canImport(AppKit)
    let font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
    let attributes: [NSAttributedString.Key: Any] = [.font: font]

    let fullSize = (source as NSString).size(withAttributes: attributes)
    if fullSize.width <= width {
        return source
    }

    let components = source.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
    guard components.count > 2 else {
        return source
    }

    // Strip leading components, keeping at least 2
    for dropCount in 1...(components.count - 2) {
        let truncated = components.dropFirst(dropCount).joined(separator: ".")
        let size = (truncated as NSString).size(withAttributes: attributes)
        if size.width <= width {
            return truncated
        }
    }

    // Return last 2 components as minimum
    return components.suffix(2).joined(separator: ".")
    #else
    // Character-count heuristic: ~7pt per character at caption2 monospaced size
    let estimatedCharWidth: CGFloat = 7.0
    let maxChars = Int(width / estimatedCharWidth)

    if source.count <= maxChars {
        return source
    }

    let components = source.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
    guard components.count > 2 else {
        return source
    }

    for dropCount in 1...(components.count - 2) {
        let truncated = components.dropFirst(dropCount).joined(separator: ".")
        if truncated.count <= maxChars {
            return truncated
        }
    }

    return components.suffix(2).joined(separator: ".")
    #endif
}
