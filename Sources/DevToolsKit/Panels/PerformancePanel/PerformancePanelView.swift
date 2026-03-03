import SwiftUI

/// Performance dashboard UI that displays metrics from a MetricsProvider.
public struct PerformancePanelView: View {
    private let provider: any MetricsProvider
    @State private var metricGroups: [MetricGroup] = []
    @State private var refreshTask: Task<Void, Never>?

    public init(provider: any MetricsProvider) {
        self.provider = provider
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if metricGroups.isEmpty {
                ContentUnavailableView(
                    "No Performance Data",
                    systemImage: "gauge",
                    description: Text("Run operations to collect performance metrics.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(metricGroups, id: \.name) { group in
                            metricGroupView(group)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear { refresh() }
        .onDisappear { refreshTask?.cancel() }
    }

    private var toolbar: some View {
        HStack {
            Text("Performance Dashboard")
                .font(.headline)
            Spacer()
            Button("Refresh") { refresh() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func metricGroupView(_ group: MetricGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(group.name)
                .font(.title3.weight(.semibold))

            HStack(spacing: 20) {
                ForEach(group.metrics, id: \.name) { metric in
                    metricCard(metric)
                }
            }
        }
    }

    private func metricCard(_ metric: Metric) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metric.name)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f", metric.value))
                .font(.title.weight(.semibold))
                .foregroundStyle(metric.color.swiftUIColor)
            Text(metric.unit)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func refresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            let groups = await provider.currentMetrics()
            await MainActor.run {
                metricGroups = groups
            }
        }
    }
}

extension MetricColor {
    var swiftUIColor: Color {
        switch self {
        case .blue: .blue
        case .purple: .purple
        case .orange: .orange
        case .red: .red
        case .green: .green
        case .gray: .gray
        }
    }
}
