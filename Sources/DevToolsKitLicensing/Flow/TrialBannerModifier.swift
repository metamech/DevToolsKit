import SwiftUI

/// A non-blocking banner showing trial days remaining.
///
/// Displayed as a pill in the top-trailing area of the window via `.safeAreaInset`.
/// Shows "X days remaining" with a "Buy Now" link.
///
/// ```swift
/// ContentView()
///     .trialBanner(manager: licensingManager) {
///         showPurchaseSheet = true
///     }
/// ```
public struct TrialBannerModifier: ViewModifier {
    let manager: LicensingManager
    let onPurchaseTapped: () -> Void

    public func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top, alignment: .trailing) {
            if case .trial(let daysRemaining) = manager.effectiveState {
                bannerView(daysRemaining: daysRemaining)
                    .padding(.trailing, 12)
                    .padding(.top, 4)
            }
        }
    }

    private func bannerView(daysRemaining: Int) -> some View {
        HStack(spacing: 6) {
            Text("\(daysRemaining) day\(daysRemaining == 1 ? "" : "s") remaining")
                .font(.caption)
                .foregroundStyle(daysRemaining <= 3 ? .orange : .secondary)

            Text("\u{00B7}")
                .foregroundStyle(.secondary)

            Button("Buy Now") {
                onPurchaseTapped()
            }
            .font(.caption.weight(.medium))
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

public extension View {
    /// Adds a non-blocking trial banner showing days remaining and a purchase link.
    func trialBanner(
        manager: LicensingManager,
        onPurchaseTapped: @escaping () -> Void
    ) -> some View {
        modifier(TrialBannerModifier(manager: manager, onPurchaseTapped: onPurchaseTapped))
    }
}
