import Foundation

/// Manages a stable enrollment identifier used for deterministic cohort and rollout assignment.
///
/// The enrollment ID is a random UUID persisted to UserDefaults. It regenerates
/// automatically after a configurable interval (default: 90 days) and can be
/// manually reset via ``reset()``.
@MainActor
public final class EnrollmentID: Sendable {
    private let idKey: String
    private let generatedAtKey: String
    private let regenerationInterval: TimeInterval

    /// Current enrollment ID. Generated on first access if not present.
    public var value: UUID {
        if let stored = UserDefaults.standard.string(forKey: idKey),
            let uuid = UUID(uuidString: stored),
            !isExpired
        {
            return uuid
        }
        return regenerate()
    }

    /// When the current enrollment ID was generated.
    public var generatedAt: Date {
        let interval = UserDefaults.standard.double(forKey: generatedAtKey)
        guard interval > 0 else { return Date() }
        return Date(timeIntervalSince1970: interval)
    }

    /// When the current enrollment ID will automatically regenerate.
    public var expiresAt: Date {
        generatedAt.addingTimeInterval(regenerationInterval)
    }

    /// Whether the current enrollment ID has expired and needs regeneration.
    private var isExpired: Bool {
        let interval = UserDefaults.standard.double(forKey: generatedAtKey)
        guard interval > 0 else { return true }
        let generated = Date(timeIntervalSince1970: interval)
        return Date().timeIntervalSince(generated) >= regenerationInterval
    }

    /// - Parameters:
    ///   - keyPrefix: UserDefaults key prefix (e.g., `"myapp"`).
    ///   - regenerationInterval: Seconds before automatic regeneration; defaults to 90 days.
    public init(keyPrefix: String, regenerationInterval: TimeInterval = 90 * 24 * 60 * 60) {
        self.idKey = "\(keyPrefix).enrollment.id"
        self.generatedAtKey = "\(keyPrefix).enrollment.generatedAt"
        self.regenerationInterval = regenerationInterval
    }

    /// Manually reset the enrollment ID, generating a new one immediately.
    ///
    /// - Returns: The new enrollment ID.
    @discardableResult
    public func reset() -> UUID {
        regenerate()
    }

    @discardableResult
    private func regenerate() -> UUID {
        let newID = UUID()
        UserDefaults.standard.set(newID.uuidString, forKey: idKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: generatedAtKey)
        return newID
    }
}
