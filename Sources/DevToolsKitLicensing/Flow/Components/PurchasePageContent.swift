import SwiftUI
import WelcomeKit

/// Purchase page showing pricing tiers and purchase actions.
///
/// Used as a custom WelcomePage via ``LicensingPages/purchase(offering:manager:devSimulationEnabled:)``.
struct PurchasePageContent: View {
    let offering: LicensingOffering
    let manager: LicensingManager
    let devSimulationEnabled: Bool

    @State private var errorMessage: String?
    @Environment(\.openURL) private var openURL
    @Environment(\.welcomeNavigator) private var navigator

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                pricingTiers
                divider
                enterKeyLink

                #if ENABLE_LICENSE_TESTING
                if devSimulationEnabled {
                    devSimulationControls
                }
                #endif

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(32)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: offering.appIconName)
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text(offering.appName)
                .font(.title2.weight(.semibold))
        }
    }

    private var pricingTiers: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(offering.pricingTiers) { tier in
                PricingTierCardView(tier: tier) {
                    Task { await purchaseTier(tier) }
                }
            }
        }
    }

    private var divider: some View {
        VStack(spacing: 8) {
            Divider()
            Text("or")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var enterKeyLink: some View {
        Button(offering.ctaText.enterKey) {
            navigator?.next()
        }
        .buttonStyle(.bordered)
    }

    #if ENABLE_LICENSE_TESTING
    private var devSimulationControls: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.vertical, 8)

            Text("License Testing")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Simulate Success") {
                    if let mock = manager.backend as? MockLicenseBackend {
                        mock.simulateActivation()
                        manager.trial?.wasEverLicensed = true
                        navigator?.dismiss()
                    }
                }
                .buttonStyle(.bordered)
                .tint(.green)

                Button("Simulate Failure") {
                    errorMessage = "Simulated purchase failure: card declined"
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }
    #endif

    private func purchaseTier(_ tier: LicensingOffering.PricingTier) async {
        errorMessage = nil

        if let handler = offering.purchaseHandler {
            do {
                try await handler(tier)
                navigator?.dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        } else if let url = tier.purchaseURL ?? offering.purchaseURL {
            openURL(url)
        }
    }
}
