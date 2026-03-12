import SwiftUI

/// Detail view for a selected metric showing entries, summary stats, and sparkline.
struct MetricDetailView: View {
    let identifier: MetricIdentifier
    let metricsManager: MetricsManager

    @State private var summary: MetricSummary?
    @State private var entries: [MetricEntry] = []
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let summary {
                summarySection(summary)
                Divider()
                sparklineSection
                Divider()
                entriesSection
            } else {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.bar",
                    description: Text("No entries found for this metric.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: identifier) {
            await loadData()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(identifier.label)
                .font(.system(.title3, design: .monospaced, weight: .semibold))

            HStack(spacing: 8) {
                Text(identifier.type.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))

                if !identifier.dimensions.isEmpty {
                    Text(identifier.dimensions.map { "\($0.0)=\($0.1)" }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
    }

    private func summarySection(_ summary: MetricSummary) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ],
            spacing: 8
        ) {
            statCard("Count", "\(summary.count)")
            statCard("Avg", String(format: "%.4f", summary.avg))
            statCard("Min", String(format: "%.4f", summary.min))
            statCard("Max", String(format: "%.4f", summary.max))
            statCard("Latest", String(format: "%.4f", summary.latest))
            statCard("p50", summary.p50.map { String(format: "%.4f", $0) } ?? "–")
            statCard("p95", summary.p95.map { String(format: "%.4f", $0) } ?? "–")
            statCard("p99", summary.p99.map { String(format: "%.4f", $0) } ?? "–")
        }
        .padding(12)
    }

    private func statCard(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
        }
        .frame(maxWidth: .infinity)
        .padding(6)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 6))
    }

    private var sparklineSection: some View {
        Group {
            if entries.count >= 2 {
                SparklineView(values: entries.map(\.value))
                    .frame(height: 60)
                    .padding(12)
            }
        }
    }

    private var entriesSection: some View {
        List(entries) { entry in
            HStack {
                Text(Self.timeFormatter.string(from: entry.timestamp))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.4f", entry.value))
                    .font(.system(.caption, design: .monospaced))
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
        }
        .listStyle(.plain)
    }

    private func loadData() async {
        isLoading = true
        summary = metricsManager.storage.summary(for: identifier)
        entries = metricsManager.storage.query(
            MetricsQuery(
                label: identifier.label,
                type: identifier.type,
                limit: 200,
                sort: .timestampDescending
            )
        )
        isLoading = false
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}

// MARK: - Sparkline

/// Minimal sparkline chart for metric values.
private struct SparklineView: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geometry in
            let minVal = values.min() ?? 0
            let maxVal = values.max() ?? 1
            let range = maxVal - minVal
            let normalizedRange = range > 0 ? range : 1

            Path { path in
                guard values.count >= 2 else { return }
                let stepX = geometry.size.width / CGFloat(values.count - 1)

                for (index, value) in values.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = geometry.size.height * (1 - CGFloat((value - minVal) / normalizedRange))
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(.blue, lineWidth: 1.5)
        }
    }
}
