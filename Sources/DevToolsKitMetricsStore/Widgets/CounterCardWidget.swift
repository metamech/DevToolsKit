import Foundation

/// View model for a counter/stat card widget.
///
/// Displays a single numeric or formatted value with a title and optional icon.
///
/// ```swift
/// let card = CounterCardWidget(title: "Sessions", icon: "terminal", value: 42)
/// ```
///
/// - Since: 0.9.0
public struct CounterCardWidget: Sendable, Equatable, Identifiable {
    public let id: String

    /// The card title.
    public let title: String

    /// SF Symbol name for the icon.
    public let icon: String

    /// The numeric value (nil if using formattedValue).
    public let numericValue: Int?

    /// Pre-formatted display value.
    public let formattedValue: String

    /// Optional subtitle below the value.
    public let subtitle: String?

    /// Creates a counter card with a numeric value.
    public init(
        title: String,
        icon: String,
        value: Int,
        subtitle: String? = nil,
        id: String? = nil
    ) {
        self.id = id ?? "counter.\(title.lowercased().replacingOccurrences(of: " ", with: "-"))"
        self.title = title
        self.icon = icon
        self.numericValue = value
        self.formattedValue = "\(value)"
        self.subtitle = subtitle
    }

    /// Creates a counter card with a pre-formatted value.
    public init(
        title: String,
        icon: String,
        formattedValue: String,
        subtitle: String? = nil,
        id: String? = nil
    ) {
        self.id = id ?? "counter.\(title.lowercased().replacingOccurrences(of: " ", with: "-"))"
        self.title = title
        self.icon = icon
        self.numericValue = nil
        self.formattedValue = formattedValue
        self.subtitle = subtitle
    }
}
