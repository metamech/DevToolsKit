/// The current state of a time-limited trial.
public enum TrialState: String, Sendable, Codable {
    /// Trial has not been started yet (first launch pending).
    case notStarted

    /// Trial is currently active and within the allowed duration.
    case active

    /// Trial period has elapsed.
    case expired
}
