import SwiftUI

/// Filter and query metric entries by type, label, dimensions, and date range.
struct MetricsQueryView: View {
    let metricsManager: MetricsManager
    @State private var queryLabel: String = ""
    @State private var queryType: MetricType?
    @State private var queryStartDate: Date = Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
    @State private var queryEndDate: Date = Date()
    @State private var useDateFilter = false
    @State private var queryLimit: String = "100"
    @State private var results: [MetricEntry] = []

    var body: some View {
        VStack(spacing: 0) {
            queryForm
            Divider()
            resultsTable
        }
    }

    private var queryForm: some View {
        HStack(spacing: 16) {
            TextField("Label filter", text: $queryLabel)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)

            Picker("Type", selection: $queryType) {
                Text("All").tag(MetricType?.none)
                ForEach(MetricType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(MetricType?.some(type))
                }
            }
            .frame(width: 160)

            Toggle("Date range", isOn: $useDateFilter)
                .toggleStyle(.checkbox)

            if useDateFilter {
                DatePicker("", selection: $queryStartDate)
                    .labelsHidden()
                    .frame(width: 160)
                Text("–")
                DatePicker("", selection: $queryEndDate)
                    .labelsHidden()
                    .frame(width: 160)
            }

            TextField("Limit", text: $queryLimit)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)

            Button("Run") { executeQuery() }
                .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var resultsTable: some View {
        Group {
            if results.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Run a query to see matching metric entries.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(results) {
                    TableColumn("Time") { entry in
                        Text(Self.timeFormatter.string(from: entry.timestamp))
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: 80, ideal: 95)

                    TableColumn("Label") { entry in
                        Text(entry.label)
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: 100, ideal: 200)

                    TableColumn("Type") { entry in
                        Text(entry.type.rawValue)
                            .font(.caption)
                    }
                    .width(min: 60, ideal: 80)

                    TableColumn("Value") { entry in
                        Text(String(format: "%.4f", entry.value))
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: 80, ideal: 100)

                    TableColumn("Dimensions") { entry in
                        Text(entry.dimensions.map { "\($0.0)=\($0.1)" }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tableStyle(.inset)
            }
        }
    }

    private func executeQuery() {
        let limit = Int(queryLimit)
        let query = MetricsQuery(
            label: queryLabel.isEmpty ? nil : queryLabel,
            type: queryType,
            startDate: useDateFilter ? queryStartDate : nil,
            endDate: useDateFilter ? queryEndDate : nil,
            limit: limit,
            sort: .timestampDescending
        )
        results = metricsManager.storage.query(query)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}
