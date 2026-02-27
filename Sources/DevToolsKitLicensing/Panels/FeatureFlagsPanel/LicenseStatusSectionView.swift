import SwiftUI

/// License status display with activation controls.
struct LicenseStatusSectionView: View {
    let licensing: LicensingManager
    @State private var showActivateSheet = false
    @State private var licenseKeyInput = ""
    @State private var offlineTokenInput = ""
    @State private var activationError: String?
    @State private var isActivating = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusSection
                entitlementsSection
                actionsSection
            }
            .padding()
        }
        .sheet(isPresented: $showActivateSheet) {
            activateSheet
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("License Status")
                .font(.title3.weight(.semibold))

            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                Text(licensing.licenseStatus.rawValue.capitalized)
                    .font(.headline)
            }
        }
    }

    private var statusIcon: String {
        switch licensing.licenseStatus {
        case .unconfigured: "questionmark.circle"
        case .active: "checkmark.seal.fill"
        case .offlineValid: "checkmark.shield.fill"
        case .inactive: "xmark.circle"
        case .invalid: "exclamationmark.triangle.fill"
        case .pending: "clock"
        }
    }

    private var statusColor: Color {
        switch licensing.licenseStatus {
        case .unconfigured: .gray
        case .active, .offlineValid: .green
        case .inactive: .orange
        case .invalid: .red
        case .pending: .blue
        }
    }

    private var entitlementsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Entitlements")
                .font(.title3.weight(.semibold))

            let entitlements = Array(licensing.backend.activeEntitlements).sorted()
            if entitlements.isEmpty {
                Text("None")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(entitlements, id: \.self) { entitlement in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(entitlement)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Actions")
                .font(.title3.weight(.semibold))

            HStack(spacing: 12) {
                Button("Activate License") {
                    showActivateSheet = true
                }
                .buttonStyle(.bordered)

                Button("Validate") {
                    Task {
                        try? await licensing.validate()
                    }
                }
                .buttonStyle(.bordered)

                Button("Deactivate") {
                    Task {
                        try? await licensing.deactivate()
                    }
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }

    private var activateSheet: some View {
        VStack(spacing: 16) {
            Text("Activate License")
                .font(.headline)

            TextField("License Key", text: $licenseKeyInput)
                .textFieldStyle(.roundedBorder)

            Divider()

            Text("Or paste offline token:")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $offlineTokenInput)
                .font(.system(.caption, design: .monospaced))
                .frame(height: 80)
                .border(Color.secondary.opacity(0.3))

            if let error = activationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") {
                    showActivateSheet = false
                    activationError = nil
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Activate") {
                    Task { await performActivation() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(licenseKeyInput.isEmpty && offlineTokenInput.isEmpty)
                .disabled(isActivating)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func performActivation() async {
        isActivating = true
        activationError = nil
        defer { isActivating = false }

        do {
            if !offlineTokenInput.isEmpty {
                try await licensing.activate(with: .offlineToken(offlineTokenInput))
            } else {
                try await licensing.activate(with: .licenseKey(licenseKeyInput))
            }
            showActivateSheet = false
        } catch {
            activationError = error.localizedDescription
        }
    }
}
