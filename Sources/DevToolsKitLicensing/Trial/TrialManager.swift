import Foundation

/// Manages a time-limited trial using UserDefaults for persistence.
///
/// The trial manager tracks when the user first launched the app and computes
/// whether the trial is still active based on the configured duration.
///
/// **UserDefaults keys** (prefixed with `{keyPrefix}.trial.`):
/// - `startDate`: TimeInterval of first trial start (written once, immutable)
/// - `durationDays`: Int days (written once from config)
/// - `hasSeenWelcome`: Bool indicating the welcome screen was shown
/// - `wasEverLicensed`: Bool set on first activation (never cleared)
///
/// **Anti-tamper**: Once the trial transitions from `active` to `expired`,
/// it stays expired regardless of clock changes. The `startDate` is immutable
/// from the public API. Only ``resetTrial()`` (for dev testing) reverses this.
///
/// ```swift
/// let trial = TrialManager(keyPrefix: "myapp", configuration: .init(durationDays: 14))
/// trial.startTrialIfNeeded()
///
/// switch trial.state {
/// case .notStarted: // show welcome
/// case .active:     // user can use the app
/// case .expired:    // hard cutoff
/// }
/// ```
@MainActor @Observable
public final class TrialManager: Sendable {
    // MARK: - Configuration

    public let configuration: TrialConfiguration

    // MARK: - Published State

    /// Current trial state, updated by ``refresh()``.
    public private(set) var state: TrialState

    // MARK: - Private

    private let startDateKey: String
    private let durationDaysKey: String
    private let hasSeenWelcomeKey: String
    private let wasEverLicensedKey: String

    // MARK: - Init

    /// - Parameters:
    ///   - keyPrefix: UserDefaults key prefix (e.g., `"myapp"`).
    ///   - configuration: Trial duration and behavior settings.
    public init(keyPrefix: String, configuration: TrialConfiguration = .init()) {
        self.configuration = configuration
        self.startDateKey = "\(keyPrefix).trial.startDate"
        self.durationDaysKey = "\(keyPrefix).trial.durationDays"
        self.hasSeenWelcomeKey = "\(keyPrefix).trial.hasSeenWelcome"
        self.wasEverLicensedKey = "\(keyPrefix).trial.wasEverLicensed"
        self.state = .notStarted

        refresh()
    }

    // MARK: - Computed Properties

    /// The date the trial was first started, or `nil` if not yet started.
    public var firstLaunchDate: Date? {
        let interval = UserDefaults.standard.double(forKey: startDateKey)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    /// The date the trial expires, or `nil` if not yet started.
    public var trialExpiryDate: Date? {
        guard let start = firstLaunchDate else { return nil }
        let days = UserDefaults.standard.integer(forKey: durationDaysKey)
        let duration = days > 0 ? days : configuration.durationDays
        return Calendar.current.date(byAdding: .day, value: duration, to: start)
    }

    /// Number of full days remaining in the trial. Returns 0 if expired or not started.
    public var daysRemaining: Int {
        guard let expiry = trialExpiryDate else { return 0 }
        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
        return max(0, remaining)
    }

    /// Whether this is the very first launch (no trial started, no welcome shown).
    public var isFirstLaunch: Bool {
        !hasSeenWelcome && firstLaunchDate == nil
    }

    /// Whether the welcome screen has been shown.
    public var hasSeenWelcome: Bool {
        get { UserDefaults.standard.bool(forKey: hasSeenWelcomeKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasSeenWelcomeKey) }
    }

    /// Whether the user has ever successfully activated a license.
    /// Set to `true` on first activation; never cleared automatically.
    public var wasEverLicensed: Bool {
        get { UserDefaults.standard.bool(forKey: wasEverLicensedKey) }
        set { UserDefaults.standard.set(newValue, forKey: wasEverLicensedKey) }
    }

    // MARK: - Actions

    /// Starts the trial if it hasn't been started yet. Idempotent.
    ///
    /// If a trial start date is already persisted, this method loads it and refreshes state.
    /// Otherwise, it records the current date as the trial start and persists the configured duration.
    public func startTrialIfNeeded() {
        if firstLaunchDate != nil {
            // Already started — just refresh
            refresh()
            return
        }

        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: startDateKey)
        UserDefaults.standard.set(configuration.durationDays, forKey: durationDaysKey)
        refresh()
    }

    /// Recalculates the trial state from persisted data and current time.
    ///
    /// Transitions are one-directional: `notStarted -> active -> expired`.
    /// Once expired, the trial stays expired regardless of clock changes.
    public func refresh() {
        guard let start = firstLaunchDate else {
            state = .notStarted
            return
        }

        guard let expiry = trialExpiryDate else {
            state = .notStarted
            return
        }

        if Date() >= expiry {
            state = .expired
        } else if Date() >= start {
            state = .active
        } else {
            // Clock was set back before start date — still treat as active
            // since the user legitimately started the trial
            state = .active
        }
    }

    /// Marks the trial as already started and welcome as already seen.
    ///
    /// Use in dev/deploy builds so developers aren't blocked by the welcome
    /// screen or trial-start flow during normal usage. The trial state will
    /// reflect the actual persisted dates (or `.notStarted` on first run,
    /// in which case it auto-starts silently).
    public func skipWelcomeIfNeeded() {
        if !hasSeenWelcome {
            hasSeenWelcome = true
        }
        startTrialIfNeeded()
    }

    /// Resets the trial completely. **For development/testing only.**
    ///
    /// Clears the start date, duration, and welcome-seen flag.
    /// Does NOT clear `wasEverLicensed`.
    public func resetTrial() {
        UserDefaults.standard.removeObject(forKey: startDateKey)
        UserDefaults.standard.removeObject(forKey: durationDaysKey)
        UserDefaults.standard.removeObject(forKey: hasSeenWelcomeKey)
        state = .notStarted
    }
}
