import SwiftUI

/// View for the code analysis panel.
///
/// Displays quality score, category breakdown, and filterable issue list.
@MainActor
struct CodeAnalysisPanelView: View {
    let result: AnalysisResult?

    @State private var selectedCategory: Category?
    @State private var selectedSeverity: Severity?

    var body: some View {
        if let result = result {
            VStack(spacing: 0) {
                scoreHeader(result)
                Divider()
                issueList(result)
            }
        } else {
            ContentUnavailableView(
                "No Analysis Results",
                systemImage: "magnifyingglass.circle",
                description: Text("Run a code analysis to see results here.")
            )
        }
    }

    // MARK: - Score Header

    @ViewBuilder
    private func scoreHeader(_ result: AnalysisResult) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                scoreCard(
                    title: "Overall",
                    score: result.score.overall,
                    grade: result.score.grade
                )
                scoreCard(title: "Security", score: result.score.security)
                scoreCard(title: "Performance", score: result.score.performance)
                scoreCard(title: "Maintainability", score: result.score.maintainability)
                scoreCard(title: "Style", score: result.score.style)
            }

            HStack {
                Label("\(result.errorCount) errors", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Label("\(result.warningCount) warnings", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Label("\(result.infoCount) info", systemImage: "info.circle.fill")
                    .foregroundStyle(.blue)
                Spacer()
                Text(result.file)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding()
    }

    @ViewBuilder
    private func scoreCard(title: String, score: Double, grade: String? = nil) -> some View {
        VStack(spacing: 4) {
            Text(grade ?? "\(Int(score))")
                .font(.title2.bold())
                .foregroundStyle(scoreColor(score))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 60)
    }

    // MARK: - Issue List

    @ViewBuilder
    private func issueList(_ result: AnalysisResult) -> some View {
        VStack(spacing: 0) {
            filterBar()
            Divider()
            List {
                ForEach(filteredIssues(result)) { issue in
                    issueRow(issue)
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func filterBar() -> some View {
        HStack {
            Picker("Category", selection: $selectedCategory) {
                Text("All Categories").tag(nil as Category?)
                ForEach(Category.allCases, id: \.self) { category in
                    Text(category.displayName).tag(category as Category?)
                }
            }
            .pickerStyle(.menu)

            Picker("Severity", selection: $selectedSeverity) {
                Text("All Severities").tag(nil as Severity?)
                ForEach(Severity.allCases, id: \.self) { severity in
                    Text(severity.displayName).tag(severity as Severity?)
                }
            }
            .pickerStyle(.menu)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func issueRow(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                severityIcon(issue.severity)
                Text(issue.message)
                    .font(.body)
                Spacer()
                Text("Line \(issue.line)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                if let code = issue.code {
                    Text(code)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Text(issue.category.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let cwe = issue.cwe {
                    Text(cwe)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(issue.recommendation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private func filteredIssues(_ result: AnalysisResult) -> [Issue] {
        var issues = result.issues
        if let category = selectedCategory {
            issues = issues.filter { $0.category == category }
        }
        if let severity = selectedSeverity {
            issues = issues.filter { $0.severity == severity }
        }
        return issues
    }

    private func severityIcon(_ severity: Severity) -> some View {
        switch severity {
        case .error:
            return Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .warning:
            return Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .info:
            return Image(systemName: "info.circle.fill").foregroundStyle(.blue)
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 90...100: return .green
        case 70..<90: return .yellow
        case 50..<70: return .orange
        default: return .red
        }
    }
}
