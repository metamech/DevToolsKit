import SwiftUI

/// A single feature flag row in the Feature Flags panel.
struct FeatureFlagRowView: View {
    let state: FeatureFlagState
    let licensing: LicensingManager

    var body: some View {
        HStack(spacing: 10) {
            statusDot
            flagInfo
            Spacer()
            badges
            overrideToggle
        }
        .padding(.vertical, 4)
    }

    private var statusDot: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 8, height: 8)
            .help(statusHelpText)
    }

    private var dotColor: Color {
        if state.isOverridden { return .purple }
        if state.isGated { return .orange }
        if state.isEnabled { return .green }
        return .gray
    }

    private var statusHelpText: String {
        if state.isOverridden { return "Developer override active" }
        if state.isGated { return "Gated by license tier" }
        if state.isEnabled { return "Enabled" }
        return "Disabled"
    }

    private var flagInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(state.definition.name)
                    .font(.system(.body, weight: .medium))
                Text(state.definition.id)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(state.definition.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var badges: some View {
        if let cohort = state.cohort {
            Text(cohort)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.blue.opacity(0.15), in: Capsule())
                .foregroundStyle(.blue)
        }

        if state.isGated {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .help("Requires higher license tier")
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

    private var overrideToggle: some View {
        Toggle(
            isOn: Binding(
                get: { state.isEnabled },
                set: { newValue in
                    licensing.setOverride(newValue, for: state.definition.id)
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
