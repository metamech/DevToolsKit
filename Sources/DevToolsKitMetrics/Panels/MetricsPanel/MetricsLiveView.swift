import SwiftUI

/// Real-time list of known metrics with latest values, grouped by label prefix.
struct MetricsLiveView: View {
    let metricsManager: MetricsManager
    @State private var selectedIdentifier: MetricIdentifier?

    var body: some View {
        #if os(macOS)
        HSplitView {
            metricsList
                .frame(minWidth: 250)

            detailPane
                .frame(minWidth: 300)
        }
        #else
        NavigationSplitView {
            metricsList
        } detail: {
            detailPane
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
            if metricsManager.filteredMetrics.isEmpty {
                ContentUnavailableView(
                    "No Metrics",
                    systemImage: "chart.bar",
                    description: Text("Metrics will appear here when the app records data via swift-metrics.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedIdentifier) {
                    ForEach(groupedMetrics, id: \.prefix) { group in
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

            if let value = metricsManager.latestValues[identifier] {
                Text(formatValue(value, type: identifier.type))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.blue)
            }
        }
    }

    private var groupedMetrics: [(prefix: String, identifiers: [MetricIdentifier])] {
        let metrics = metricsManager.filteredMetrics
        var groups: [String: [MetricIdentifier]] = [:]

        for metric in metrics {
            let prefix = labelPrefix(metric.label)
            groups[prefix, default: []].append(metric)
        }

        return groups
            .map { (prefix: $0.key, identifiers: $0.value) }
            .sorted { $0.prefix < $1.prefix }
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
            // Nanoseconds -> milliseconds
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
