import SwiftUI

/// A card displaying a single pricing tier with purchase action.
struct PricingTierCardView: View {
    let tier: LicensingOffering.PricingTier
    let onPurchase: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if tier.isPopular {
                Text("Popular")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.tint, in: Capsule())
            }

            Text(tier.name)
                .font(.headline)

            VStack(spacing: 2) {
                Text(tier.price)
                    .font(.title.weight(.bold))
                if let period = tier.period {
                    Text(period)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !tier.includedFeatures.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(tier.includedFeatures, id: \.self) { feature in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text(feature)
                                .font(.caption)
                        }
                    }
                }
            }

            Button("Purchase") {
                onPurchase()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(minWidth: 200)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tier.isPopular ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}
