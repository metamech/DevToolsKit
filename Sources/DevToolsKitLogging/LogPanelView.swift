import SwiftUI
import DevToolsKit

/// Log viewer UI showing aggregated, filterable log entries.
public struct LogPanelView: View {
    @Bindable var logStore: DevToolsLogStore
    @State private var autoScroll = true

    public init(logStore: DevToolsLogStore) {
        self.logStore = logStore
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if logStore.filteredEntries.isEmpty {
                ContentUnavailableView(
                    "No Log Entries",
                    systemImage: "doc.text",
                    description: Text("Log entries will appear here when the app generates output.")
                )
            } else {
                ScrollViewReader { proxy in
                    List(logStore.filteredEntries) { entry in
                        LogEntryRow(entry: entry)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                            .id(entry.id)
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
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("Level", selection: $logStore.filterLevel) {
                Text("Debug").tag(DevToolsLogLevel.debug)
                Text("Info").tag(DevToolsLogLevel.info)
                Text("Warning").tag(DevToolsLogLevel.warning)
                Text("Error").tag(DevToolsLogLevel.error)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)

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

            Toggle("Auto-scroll", isOn: $autoScroll)
                .toggleStyle(.checkbox)
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

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let entry: DevToolsLogEntry

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(Self.timeFormatter.string(from: entry.timestamp))
                .foregroundStyle(.secondary)
                .frame(width: 85, alignment: .leading)

            Text(levelText)
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(levelColor, in: RoundedRectangle(cornerRadius: 3))
                .frame(width: 50)

            Text(entry.source)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
                .lineLimit(1)

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
        case .debug: "DBG"
        case .info: "INF"
        case .warning: "WRN"
        case .error: "ERR"
        }
    }

    private var levelColor: Color {
        switch entry.level {
        case .debug: .gray
        case .info: .blue
        case .warning: .orange
        case .error: .red
        }
    }
}
