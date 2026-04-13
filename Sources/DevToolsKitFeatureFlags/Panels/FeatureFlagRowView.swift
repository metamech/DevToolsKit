import SwiftUI

/// A single feature flag row in the Feature Flags panel.
///
/// Takes a `flagID` and an `@Observable` `FeatureFlagStore` instead of a stale
/// `FeatureFlagState` snapshot, fixing the toggle binding bug where clicks
/// didn't reflect in the UI.
struct FeatureFlagRowView: View {
    let flagID: String
    let store: FeatureFlagStore

    var body: some View {
        if let state = store.state(for: flagID) {
            HStack(spacing: 10) {
                statusDot(state)
                flagInfo(state)
                Spacer()
                badges(state)
                overrideToggle
            }
            .padding(.vertical, 4)
        }
    }

    private func statusDot(_ state: FlagState) -> some View {
        Circle()
            .fill(dotColor(state))
            .frame(width: 8, height: 8)
            .help(statusHelpText(state))
    }

    private func dotColor(_ state: FlagState) -> Color {
        if state.isOverridden { return .purple }
        if case .strategy(let name, _) = state.resolution, name.contains("Tier") { return .orange }
        if state.isEnabled { return .green }
        return .gray
    }

    private func statusHelpText(_ state: FlagState) -> String {
        if state.isOverridden { return "Developer override active" }
        if case .strategy(let name, let detail) = state.resolution {
            return "\(name)\(detail.map { ": \($0)" } ?? "")"
        }
        if state.isEnabled { return "Enabled" }
        return "Disabled"
    }

    private func flagInfo(_ state: FlagState) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(state.flag.name)
                    .font(.system(.body, weight: .medium))
                Text(state.flag.id)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(state.flag.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private func badges(_ state: FlagState) -> some View {
        if case .strategy(let name, let detail) = state.resolution {
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.15), in: Capsule())
                    .foregroundStyle(.blue)
            }

            if name.contains("Tier") && !state.isEnabled {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .help("Requires higher license tier")
            }
        }

        if let expiresAt = state.overrideExpiresAt {
            let remaining = expiresAt.timeIntervalSinceNow
            if remaining > 0 {
                Text(formatTTL(remaining))
                    .font(.caption2)
                    .foregroundStyle(.purple)
                    .help("Override expires at \(expiresAt.formatted())")
            }
        }
    }

    /// Toggle that reads LIVE state from the store on every evaluation.
    /// This fixes the stale-snapshot bug in the old FeatureFlagRowView.
    private var overrideToggle: some View {
        Toggle(
            isOn: Binding(
                get: { store.state(for: flagID)?.isEnabled ?? false },
                set: { newValue in
                    store.setOverride(newValue, for: flagID)
                }
            )
        ) {
            EmptyView()
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private func formatTTL(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return "\(Int(seconds))s" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        return "\(Int(seconds / 3600))h"
    }
}
