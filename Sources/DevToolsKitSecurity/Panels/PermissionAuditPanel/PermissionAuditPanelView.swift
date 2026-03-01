import SwiftUI

/// View displaying the permission audit log.
@MainActor
struct PermissionAuditPanelView: View {
    let store: PermissionAuditStore

    @State private var filterText = ""
    @State private var filterCategory: OperationCategory?

    private var filteredEntries: [PermissionAuditEntry] {
        store.entries.filter { entry in
            if let filterCategory, entry.category != filterCategory {
                return false
            }
            if !filterText.isEmpty {
                return entry.operationName.localizedCaseInsensitiveContains(filterText)
                    || entry.argumentsSummary.localizedCaseInsensitiveContains(filterText)
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                TextField("Filter...", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)

                Picker("Category", selection: $filterCategory) {
                    Text("All").tag(nil as OperationCategory?)
                    Text("Read").tag(OperationCategory.read as OperationCategory?)
                    Text("Write").tag(OperationCategory.write as OperationCategory?)
                    Text("Execute").tag(OperationCategory.execute as OperationCategory?)
                    Text("Skill").tag(OperationCategory.skill as OperationCategory?)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)

                Spacer()

                Text("\(filteredEntries.count) entries")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Button("Clear") {
                    store.clear()
                }
                .buttonStyle(.borderless)
            }
            .padding(8)

            Divider()

            // List
            if filteredEntries.isEmpty {
                ContentUnavailableView(
                    "No Audit Entries",
                    systemImage: "lock.shield",
                    description: Text("Permission decisions will appear here.")
                )
            } else {
                List(filteredEntries) { entry in
                    HStack {
                        decisionIcon(for: entry.decision)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(entry.operationName)
                                    .font(.body.monospaced())
                                    .fontWeight(.medium)

                                Text(entry.category.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary)
                                    .clipShape(Capsule())
                            }

                            if !entry.argumentsSummary.isEmpty {
                                Text(entry.argumentsSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(entry.source.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)

                            Text(entry.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func decisionIcon(for decision: PermissionResponse) -> some View {
        switch decision {
        case .allow, .allowForSession:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .deny:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
