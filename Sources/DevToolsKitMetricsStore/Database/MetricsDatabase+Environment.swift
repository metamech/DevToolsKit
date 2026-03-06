import SwiftUI

/// SwiftUI environment integration for ``MetricsDatabase``.
///
/// > Since: 0.3.0
extension EnvironmentValues {
    /// The metrics database available in the environment.
    @Entry public var metricsDatabase: MetricsDatabase?
}

extension View {
    /// Sets the metrics database for this view and its descendants.
    public func metricsDatabase(_ database: MetricsDatabase) -> some View {
        environment(\.metricsDatabase, database)
    }
}
