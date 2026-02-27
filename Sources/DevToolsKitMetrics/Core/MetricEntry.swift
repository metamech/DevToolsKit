import Foundation

/// The type of metric being recorded.
public enum MetricType: String, Codable, Sendable, CaseIterable {
    case counter
    case floatingPointCounter
    case meter
    case recorder
    case timer
}

/// A single recorded metric data point.
public struct MetricEntry: Identifiable, Sendable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let label: String
    public let dimensions: [(String, String)]
    public let type: MetricType
    public let value: Double

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        label: String,
        dimensions: [(String, String)],
        type: MetricType,
        value: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.label = label
        self.dimensions = dimensions
        self.type = type
        self.value = value
    }

    // MARK: - Custom Codable for tuple-based dimensions

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, label, dimensions, type, value
    }

    private struct DimensionPair: Codable {
        let key: String
        let value: String
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(label, forKey: .label)
        try container.encode(type, forKey: .type)
        try container.encode(value, forKey: .value)
        let pairs = dimensions.map { DimensionPair(key: $0.0, value: $0.1) }
        try container.encode(pairs, forKey: .dimensions)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        label = try container.decode(String.self, forKey: .label)
        type = try container.decode(MetricType.self, forKey: .type)
        value = try container.decode(Double.self, forKey: .value)
        let pairs = try container.decode([DimensionPair].self, forKey: .dimensions)
        dimensions = pairs.map { ($0.key, $0.value) }
    }
}
