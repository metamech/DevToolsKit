import DevToolsKit
import SwiftUI

/// Main view for the Feature Flags panel.
public struct FeatureFlagsPanelView: View {
    let licensing: LicensingManager
    @State private var selectedTab = Tab.flags
    @State private var searchText = ""

    enum Tab: String, CaseIterable {
        case flags = "Flags"
        case license = "License"
        case enrollment = "Enrollment"
    }

    public init(licensing: LicensingManager) {
        self.licensing = licensing
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            tabContent
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("Tab", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)

            if selectedTab == .flags {
                TextField("Search flags...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
            }

            Spacer()

            if selectedTab == .flags {
                Text("\(licensing.flagDefinitions.count) flags")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Clear Overrides") {
                    licensing.clearAllOverrides()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .flags:
            flagsList
        case .license:
            LicenseStatusSectionView(licensing: licensing)
        case .enrollment:
            EnrollmentIDSectionView(licensing: licensing)
        }
    }

    private var flagsList: some View {
        let states = licensing.allFlagStates
        let grouped = Dictionary(grouping: states) { $0.definition.category }
        let categories = grouped.keys.sorted()

        let filtered: [(String, [FeatureFlagState])]
        if searchText.isEmpty {
            filtered = categories.compactMap { key in
                grouped[key].map { (key, $0) }
            }
        } else {
            filtered = categories.compactMap { category in
                let matching = (grouped[category] ?? []).filter { state in
                    state.definition.name.localizedCaseInsensitiveContains(searchText)
                        || state.definition.id.localizedCaseInsensitiveContains(searchText)
                        || state.definition.description.localizedCaseInsensitiveContains(searchText)
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
                            ? "Register flags with LicensingManager to see them here."
                            : "No flags match your search.")
                )
            } else {
                List {
                    ForEach(filtered, id: \.0) { category, states in
                        Section(category) {
                            ForEach(states, id: \.definition.id) { state in
                                FeatureFlagRowView(state: state, licensing: licensing)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}
