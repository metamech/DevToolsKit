import SwiftUI

/// View displaying GitHub API status.
@MainActor
struct GitHubStatusPanelView: View {
    let client: GitHubClient

    @State private var cacheCount = 0
    @State private var cacheExpired = 0

    var body: some View {
        List {
            Section("Cache") {
                LabeledContent("Entries", value: "\(cacheCount)")
                LabeledContent("Expired", value: "\(cacheExpired)")
            }

            Section("Info") {
                LabeledContent("Auth", value: ProcessInfo.processInfo.environment["GITHUB_TOKEN"] != nil ? "Token configured" : "Unauthenticated")
                LabeledContent("Rate Limit", value: ProcessInfo.processInfo.environment["GITHUB_TOKEN"] != nil ? "5,000/hour" : "60/hour")
            }
        }
        .task {
            await refreshStats()
        }
        .toolbar {
            Button("Refresh") {
                Task { await refreshStats() }
            }
        }
    }

    private func refreshStats() async {
        let stats = await client.cacheStats()
        cacheCount = stats.count
        cacheExpired = stats.expiredCount
    }
}
