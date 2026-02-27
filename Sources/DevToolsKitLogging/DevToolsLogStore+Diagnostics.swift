import DevToolsKit

extension DevToolsLogStore: DiagnosticLogProvider {
    public func diagnosticLogEntries(limit: Int) -> [DiagnosticReport.LogEntrySnapshot] {
        recentEntries(limit).map { entry in
            DiagnosticReport.LogEntrySnapshot(
                timestamp: entry.timestamp,
                level: entry.level.rawValue,
                source: entry.source,
                message: entry.message
            )
        }
    }
}
