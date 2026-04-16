import SwiftUI

/// Summary statistics table with percentiles and top metrics by frequency.
struct MetricsReportView: View {
    let metricsManager: MetricsManager

    var body: some View {
        Group {
            if summaries.isEmpty {
                ContentUnavailableView(
                    "No Metrics to Report",
                    systemImage: "chart.bar.doc.horizontal",
                    description: Text("Metrics summaries will appear here once data is recorded.")
                )
                .padding(.top, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                Table(summaries) {
                    TableColumn("Label") { summary in
                        Text(summary.identifier.label)
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: 120, ideal: 200)

                    TableColumn("Type") { summary in
                        Text(summary.identifier.type.rawValue)
                            .font(.caption)
                    }
                    .width(min: 60, ideal: 80)

                    TableColumn("Count") { summary in
                        Text("\(summary.count)")
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: 50, ideal: 60)

                    TableColumn("Avg") { summary in
                        Text(String(format: "%.2f", summary.avg))
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: 60, ideal: 80)

                    TableColumn("Min") { summary in
                        Text(String(format: "%.2f", summary.min))
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: 60, ideal: 80)

                    TableColumn("Max") { summary in
                        Text(String(format: "%.2f", summary.max))
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: 60, ideal: 80)

                    TableColumn("p50") { summary in
                        Text(summary.p50.map { String(format: "%.2f", $0) } ?? "–")
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: 50, ideal: 60)

                    TableColumn("p95") { summary in
                        Text(summary.p95.map { String(format: "%.2f", $0) } ?? "–")
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: 50, ideal: 60)

                    TableColumn("p99") { summary in
                        Text(summary.p99.map { String(format: "%.2f", $0) } ?? "–")
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: 50, ideal: 60)
                }
                .tableStyle(.inset)
            }
        }
    }

    private var summaries: [MetricSummary] {
        metricsManager.filteredMetrics.compactMap { identifier in
            metricsManager.storage.summary(for: identifier)
        }
    }
}
