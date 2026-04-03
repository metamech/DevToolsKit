import DevToolsKit
import Foundation

/// Protocol for app-defined experimental feature enums.
///
/// Conforming types define the set of experimental features in your app,
/// including prerequisite chains and build-tier defaults. Used with
/// ``ExperimentalFeatureGate`` to evaluate feature availability.
///
/// ```swift
/// enum MyFeature: String, ExperimentalFeatureProtocol, CaseIterable {
///     case darkMode
///     case aiAssist
///
///     var prerequisites: [MyFeature] { [] }
///
///     func defaultEnabled(for channel: DistributionChannel) -> Bool {
///         switch channel {
///         case .website: true
///         case .appStore: false
///         }
///     }
/// }
/// ```
///
/// - Since: 0.9.0
public protocol ExperimentalFeatureProtocol: RawRepresentable, CaseIterable, Sendable
where RawValue == String {
    /// Features that must also be enabled for this feature to be active.
    var prerequisites: [Self] { get }

    /// The default enabled state when no developer override exists.
    ///
    /// - Parameter channel: The app's distribution channel (website vs App Store).
    /// - Returns: `true` if the feature should be enabled by default for this channel.
    func defaultEnabled(for channel: DistributionChannel) -> Bool
}
