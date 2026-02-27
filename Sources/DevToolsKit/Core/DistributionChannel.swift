import Foundation

/// Distribution channel for the app, used by DevToolsKit modules to vary behavior.
///
/// Modules that differ by distribution channel split into separate SPM targets.
/// For example, `DevToolsKitLicensingSeat` is used for website distribution and
/// `DevToolsKitLicensingStoreKit` for App Store distribution. The integrating app
/// imports only the target appropriate for its channel.
///
/// **Build flag convention:** Set `APPSTORE_BUILD` in the app target's Swift compiler
/// flags for App Store builds. Modules may check this at compile time via
/// `#if APPSTORE_BUILD`.
public enum DistributionChannel: String, Sendable, CaseIterable, Codable {
    /// Direct distribution: LemonSqueezy/LicenseSeat licensing, Sparkle updates.
    case website

    /// Mac App Store: StoreKit IAP, system auto-update.
    case appStore
}
