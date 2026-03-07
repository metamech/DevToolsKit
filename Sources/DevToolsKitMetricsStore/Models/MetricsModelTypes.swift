import SwiftData

/// Provides all SwiftData model types used by DevToolsKitMetricsStore.
///
/// Use ``all`` when constructing a `ModelContainer` schema that includes
/// metrics persistence:
/// ```swift
/// let schema = Schema(MetricsModelTypes.all)
/// let container = try ModelContainer(for: schema)
/// ```
///
/// > Since: 0.3.0
public enum MetricsModelTypes {
    /// All persistent model types required for metrics storage.
    public static var all: [any PersistentModel.Type] {
        [
            MetricObservation.self,
            MetricDimension.self,
            MetricRollup.self,
            MetricDefinition.self,
        ]
    }
}
