import DevToolsKit
import SwiftUI

/// Tab selection for the metrics panel.
enum MetricsPanelTab: String, CaseIterable {
    case live = "Live"
    case query = "Query"
    case report = "Report"
}

/// Main view for the metrics panel with Live, Query, and Report tabs.
public struct MetricsPanelView: View {
    @Bindable var metricsManager: MetricsManager
    @State private var selectedTab: MetricsPanelTab = .live

    public init(metricsManager: MetricsManager) {
        self.metricsManager = metricsManager
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            Group {
                switch selectedTab {
                case .live:
                    MetricsLiveView(metricsManager: metricsManager)
                case .query:
                    MetricsQueryView(metricsManager: metricsManager)
                case .report:
                    MetricsReportView(metricsManager: metricsManager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("Tab", selection: $selectedTab) {
                ForEach(MetricsPanelTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)

            TextField("Search...", text: $metricsManager.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)

            Spacer()

            Text("\(metricsManager.totalEntries) entries")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: { Task { await metricsManager.clear() } }) {
                Image(systemName: "trash")
            }
            .help("Clear all metrics")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
