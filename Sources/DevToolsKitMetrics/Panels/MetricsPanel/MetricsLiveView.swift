import SwiftUI

/// Real-time list of known metrics with latest values, grouped by label prefix.
struct MetricsLiveView: View {
    let metricsManager: MetricsManager
    @State private var selectedIdentifier: MetricIdentifier?
    @State private var displayedGroups: [(prefix: String, identifiers: [MetricIdentifier])] = []
    @State private var displayedLatestValues: [MetricIdentifier: Double] = [:]
    @State private var isLoading = true
    @State private var refreshID = UUID()

    var body: some View {
        #if os(macOS)
        HSplitView {
            metricsList
                .frame(minWidth: 250)

            detailPane
                .frame(minWidth: 300)
        }
        .task(id: refreshID) {
            await loadMetrics()
        }
        .task(id: FilterKey(searchText: metricsManager.searchText, filterType: metricsManager.filterType)) {
            await loadMetrics()
        }
        #else
        NavigationSplitView {
            metricsList
        } detail: {
            detailPane
        }
        .task(id: refreshID) {
            await loadMetrics()
        }
        .task(id: FilterKey(searchText: metricsManager.searchText, filterType: metricsManager.filterType)) {
            await loadMetrics()
        }
        #endif
    }

    @ViewBuilder
    private var detailPane: some View {
        if let selectedIdentifier {
            MetricDetailView(
                identifier: selectedIdentifier,
                metricsManager: metricsManager
            )
        } else {
            ContentUnavailableView(
                "Select a Metric",
                systemImage: "chart.bar",
                description: Text("Choose a metric from the list to view details.")
            )
        }
    }

    private var metricsList: some View {
        Group {
            if isLoading && displayedGroups.isEmpty {
                ProgressView("Loading metrics…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if displayedGroups.isEmpty {
                ContentUnavailableView(
                    "No Metrics",
                    systemImage: "chart.bar",
                    description: Text("Metrics will appear here when the app records data via swift-metrics.")
                )
                .padding(.top, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                List(selection: $selectedIdentifier) {
                    ForEach(displayedGroups, id: \.prefix) { group in
                        Section(group.prefix) {
                            ForEach(group.identifiers, id: \.self) { identifier in
                                metricRow(identifier)
                                    .tag(identifier)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    private func metricRow(_ identifier: MetricIdentifier) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(identifier.label)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                Text(identifier.type.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let value = displayedLatestValues[identifier] {
                Text(formatValue(value, type: identifier.type))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.blue)
            }
        }
    }

    private func loadMetrics() async {
        isLoading = true

        // Yield so the view renders the ProgressView immediately before
        // the synchronous data-fetch work blocks the main actor.
        await Task.yield()

        let metrics = metricsManager.filteredMetrics
        let latestValues = metricsManager.latestValues

        var groups: [String: [MetricIdentifier]] = [:]
        for metric in metrics {
            let prefix = labelPrefix(metric.label)
            groups[prefix, default: []].append(metric)
        }
        let sorted = groups
            .map { (prefix: $0.key, identifiers: $0.value) }
            .sorted { $0.prefix < $1.prefix }

        displayedGroups = sorted
        displayedLatestValues = latestValues
        isLoading = false

        // Auto-refresh after a delay to pick up new metrics
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled else { return }
        refreshID = UUID()
    }

    private func labelPrefix(_ label: String) -> String {
        if let dotIndex = label.firstIndex(of: ".") {
            return String(label[...dotIndex])
        }
        return label
    }

    private func formatValue(_ value: Double, type: MetricType) -> String {
        switch type {
        case .timer:
            let ms = value / 1_000_000
            return String(format: "%.2f ms", ms)
        default:
            if value == value.rounded() && abs(value) < 1e15 {
                return String(format: "%.0f", value)
            }
            return String(format: "%.4f", value)
        }
    }
}

/// Hashable key for filter-change tracking in `.task(id:)`.
private struct FilterKey: Equatable {
    let searchText: String
    let filterType: MetricType?
}
