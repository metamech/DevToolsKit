import DevToolsKitLicensing
import Foundation
import StoreKit

/// License backend for App Store-distributed apps using StoreKit 2.
///
/// Maps StoreKit product IDs to named entitlement strings. The backend monitors
/// transaction updates and resolves entitlements from current subscriptions and
/// purchased products.
///
/// ```swift
/// import DevToolsKitLicensingStoreKit
///
/// let backend = StoreKitBackend(entitlementMap: [
///     "com.myapp.pro.monthly": ["premium"],
///     "com.myapp.enterprise": ["premium", "enterprise"],
/// ])
/// let licensing = LicensingManager(keyPrefix: "myapp", backend: backend)
/// ```
@MainActor
public final class StoreKitBackend: LicenseBackend, @unchecked Sendable {
    /// Maps product IDs to the entitlement names they grant.
    private let entitlementMap: [String: [String]]

    /// Current license status.
    public private(set) var status: DevToolsLicenseStatus = .unconfigured

    /// Active entitlement names resolved from current StoreKit transactions.
    public private(set) var activeEntitlements: Set<String> = []

    private var transactionListener: Task<Void, Never>?

    /// - Parameter entitlementMap: Dictionary mapping StoreKit product IDs to entitlement name arrays.
    public init(entitlementMap: [String: [String]]) {
        self.entitlementMap = entitlementMap
        startTransactionListener()
        Task { await refreshEntitlements() }
    }

    deinit {
        transactionListener?.cancel()
    }

    public func activate(with credential: LicenseCredential) async throws {
        // StoreKit handles purchases via its own UI. This is a no-op; the
        // transaction listener picks up purchases automatically.
        await refreshEntitlements()
    }

    public func validate() async throws {
        await refreshEntitlements()
    }

    public func deactivate() async throws {
        // Cannot programmatically cancel a subscription — user must do this
        // through system settings. We just refresh the state.
        await refreshEntitlements()
    }

    // MARK: - Transaction Monitoring

    private func startTransactionListener() {
        transactionListener = Task(priority: .utility) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified = result {
                    await self.refreshEntitlements()
                }
            }
        }
    }

    private func refreshEntitlements() async {
        var newEntitlements: Set<String> = []

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if let entitlements = entitlementMap[transaction.productID] {
                    for entitlement in entitlements {
                        newEntitlements.insert(entitlement)
                    }
                }
            }
        }

        activeEntitlements = newEntitlements

        if newEntitlements.isEmpty {
            status = .inactive
        } else {
            status = .active
        }
    }
}
