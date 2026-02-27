import SwiftUI

/// Displays the enrollment ID with its generation and expiry dates, plus manual reset.
struct EnrollmentIDSectionView: View {
    let licensing: LicensingManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                enrollmentSection
                infoSection
            }
            .padding()
        }
    }

    private var enrollmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enrollment ID")
                .font(.title3.weight(.semibold))

            Text(licensing.enrollmentID.uuidString)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)

            HStack(spacing: 12) {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        licensing.enrollmentID.uuidString, forType: .string)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Reset") {
                    licensing.resetEnrollmentID()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.orange)
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.title3.weight(.semibold))

            infoRow("Generated", value: licensing.enrollment.generatedAt.formatted())
            infoRow("Expires", value: licensing.enrollmentIDExpiresAt.formatted())
            infoRow(
                "Time Until Regeneration",
                value: formatTimeRemaining(licensing.enrollmentIDExpiresAt.timeIntervalSinceNow))
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 180, alignment: .trailing)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "Expired" }
        let days = Int(seconds / 86400)
        let hours = Int(seconds.truncatingRemainder(dividingBy: 86400) / 3600)
        if days > 0 { return "\(days)d \(hours)h" }
        let minutes = Int(seconds.truncatingRemainder(dividingBy: 3600) / 60)
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
