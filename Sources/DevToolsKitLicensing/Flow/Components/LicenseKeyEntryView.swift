import SwiftUI
import WelcomeKit

/// A reusable license key entry form with activation support.
public struct LicenseKeyEntryView: View {
    let manager: LicensingManager

    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var errorMessage: String?
    @Environment(\.welcomeNavigator) private var navigator

    public init(manager: LicensingManager) {
        self.manager = manager
    }

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Enter License Key")
                .font(.title2.weight(.semibold))

            VStack(spacing: 12) {
                TextField("Paste your license key", text: $licenseKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: 400)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await activate() }
                } label: {
                    if isActivating {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: 280)
                    } else {
                        Text("Activate")
                            .frame(maxWidth: 280)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(licenseKey.trimmingCharacters(in: .whitespaces).isEmpty || isActivating)
            }

            Spacer()
        }
        .padding()
    }

    private func activate() async {
        isActivating = true
        errorMessage = nil
        defer { isActivating = false }

        do {
            try await manager.activate(with: .licenseKey(licenseKey.trimmingCharacters(in: .whitespaces)))
            manager.trial?.wasEverLicensed = true
            navigator?.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
