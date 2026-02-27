/// Protocol for providing log entries to the diagnostic exporter.
///
/// Conform to this protocol to supply log data without requiring
/// a direct dependency on `DevToolsLogStore` or swift-log.
@MainActor
public protocol DiagnosticLogProvider: Sendable {
    /// Return recent log entries as snapshots for diagnostic export.
    ///
    /// - Parameter limit: Maximum number of entries to return.
    /// - Returns: An array of log entry snapshots, most recent last.
    func diagnosticLogEntries(limit: Int) -> [DiagnosticReport.LogEntrySnapshot]
}
