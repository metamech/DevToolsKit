import Foundation
import SwiftData

/// A key-value dimension pair associated with a ``MetricObservation``.
///
/// > Since: 0.3.0
@Model
public final class MetricDimension {
    /// The dimension key (e.g. "env", "region").
    public var key: String
    /// The dimension value (e.g. "prod", "us-east-1").
    public var value: String
    /// The observation this dimension belongs to.
    public var observation: MetricObservation?

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}
