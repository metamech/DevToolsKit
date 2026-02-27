import Foundation

/// Uniquely identifies a metric by its label, dimensions, and type.
///
/// Dimensions are sorted before comparison so that order does not affect identity.
public struct MetricIdentifier: Sendable, Codable {
    public let label: String
    public let dimensions: [(String, String)]
    public let type: MetricType

    public init(label: String, dimensions: [(String, String)], type: MetricType) {
        self.label = label
        self.dimensions = dimensions
        self.type = type
    }

    /// Creates an identifier from a ``MetricEntry``.
    public init(entry: MetricEntry) {
        self.label = entry.label
        self.dimensions = entry.dimensions
        self.type = entry.type
    }

    /// Dimensions sorted by key then value, used for stable comparison.
    private var sortedDimensions: [(String, String)] {
        dimensions.sorted { lhs, rhs in
            lhs.0 == rhs.0 ? lhs.1 < rhs.1 : lhs.0 < rhs.0
        }
    }

    // MARK: - Custom Codable for tuple-based dimensions

    private enum CodingKeys: String, CodingKey {
        case label, dimensions, type
    }

    private struct DimensionPair: Codable {
        let key: String
        let value: String
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(label, forKey: .label)
        try container.encode(type, forKey: .type)
        let pairs = dimensions.map { DimensionPair(key: $0.0, value: $0.1) }
        try container.encode(pairs, forKey: .dimensions)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        type = try container.decode(MetricType.self, forKey: .type)
        let pairs = try container.decode([DimensionPair].self, forKey: .dimensions)
        dimensions = pairs.map { ($0.key, $0.value) }
    }
}

extension MetricIdentifier: Equatable {
    public static func == (lhs: MetricIdentifier, rhs: MetricIdentifier) -> Bool {
        lhs.label == rhs.label
            && lhs.type == rhs.type
            && lhs.sortedDimensions.elementsEqual(rhs.sortedDimensions) { $0.0 == $1.0 && $0.1 == $1.1 }
    }
}

extension MetricIdentifier: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(label)
        hasher.combine(type)
        for (key, value) in sortedDimensions {
            hasher.combine(key)
            hasher.combine(value)
        }
    }
}
