import DevToolsKit
import SwiftUI

/// Main view for the Feature Flags panel.
public struct FeatureFlagsPanelView: View {
    let store: FeatureFlagStore
    @State private var searchText = ""

    public init(store: FeatureFlagStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            flagsList
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            TextField("Search flags...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)

            Spacer()

            Text("\(store.flagDefinitions.count) flags")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Clear Overrides") {
                store.clearAllOverrides()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var flagsList: some View {
        let states = store.allStates
        let grouped = Dictionary(grouping: states) { $0.flag.category }
        let categories = grouped.keys.sorted()

        let filtered: [(String, [FlagState])]
        if searchText.isEmpty {
            filtered = categories.compactMap { key in
                grouped[key].map { (key, $0) }
            }
        } else {
            filtered = categories.compactMap { category in
                let matching = (grouped[category] ?? []).filter { state in
                    state.flag.name.localizedCaseInsensitiveContains(searchText)
                        || state.flag.id.localizedCaseInsensitiveContains(searchText)
                        || state.flag.description.localizedCaseInsensitiveContains(searchText)
                }
                return matching.isEmpty ? nil : (category, matching)
            }
        }

        return Group {
            if filtered.isEmpty {
                ContentUnavailableView(
                    "No Feature Flags",
                    systemImage: "flag",
                    description: Text(
                        searchText.isEmpty
                            ? "Register flags with FeatureFlagStore to see them here."
                            : "No flags match your search.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filtered, id: \.0) { category, states in
                        Section(category) {
                            ForEach(states, id: \.flag.id) { state in
                                FeatureFlagRowView(flagID: state.flag.id, store: store)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}
