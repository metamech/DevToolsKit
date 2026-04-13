import Foundation

/// A local targeting rule for experiment eligibility or rollout gating.
///
/// All checks are local — no GPS, no network. Version comparisons use numeric
/// component comparison (e.g., "15.2" < "15.10").
public enum TargetingRule: Sendable, Hashable, Codable {
    /// User's app version must be at least this value.
    case minimumAppVersion(String)

    /// User's app version must be at most this value.
    case maximumAppVersion(String)

    /// User's macOS version must be at least this value.
    case minimumOSVersion(String)

    /// User's macOS version must be at most this value.
    case maximumOSVersion(String)

    /// User's system language code must match (e.g., `"en"`, `"ja"`).
    case language(String)

    /// User's system region code must match (e.g., `"US"`, `"JP"`).
    case region(String)

    /// Evaluate whether this rule is satisfied on the current system.
    ///
    /// - Returns: `true` if the user's environment matches the rule.
    public func isSatisfied() -> Bool {
        switch self {
        case .minimumAppVersion(let version):
            guard let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            else { return false }
            return compareVersions(appVersion, isAtLeast: version)

        case .maximumAppVersion(let version):
            guard let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            else { return false }
            return compareVersions(version, isAtLeast: appVersion)

        case .minimumOSVersion(let version):
            let osVersion = ProcessInfo.processInfo.operatingSystemVersion
            let osString = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
            return compareVersions(osString, isAtLeast: version)

        case .maximumOSVersion(let version):
            let osVersion = ProcessInfo.processInfo.operatingSystemVersion
            let osString = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
            return compareVersions(version, isAtLeast: osString)

        case .language(let code):
            let current = Locale.current.language.languageCode?.identifier ?? ""
            return current == code

        case .region(let code):
            let current = Locale.current.region?.identifier ?? ""
            return current == code
        }
    }
}

/// Compare two version strings numerically (e.g., "2.1.0" >= "2.0.3").
private func compareVersions(_ lhs: String, isAtLeast rhs: String) -> Bool {
    let lhsParts = lhs.split(separator: ".").compactMap { Int($0) }
    let rhsParts = rhs.split(separator: ".").compactMap { Int($0) }
    let maxCount = max(lhsParts.count, rhsParts.count)
    for i in 0..<maxCount {
        let l = i < lhsParts.count ? lhsParts[i] : 0
        let r = i < rhsParts.count ? rhsParts[i] : 0
        if l < r { return false }
        if l > r { return true }
    }
    return true
}
