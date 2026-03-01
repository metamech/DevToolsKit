import Foundation

/// Request for permission to execute an operation.
///
/// Since 0.4.0
public struct PermissionRequest: Sendable {
    /// Name of the operation requesting permission.
    public let operationName: String

    /// Category of the operation.
    public let operationCategory: OperationCategory

    /// Arguments passed to the operation.
    public let arguments: [String: String]

    /// Risk level of this operation.
    public let riskLevel: RiskLevel

    /// Creates a permission request.
    /// - Parameters:
    ///   - operationName: Name of the operation.
    ///   - operationCategory: Category of the operation.
    ///   - arguments: Arguments passed to the operation.
    ///   - riskLevel: Risk level of this operation.
    public init(
        operationName: String,
        operationCategory: OperationCategory,
        arguments: [String: String],
        riskLevel: RiskLevel
    ) {
        self.operationName = operationName
        self.operationCategory = operationCategory
        self.arguments = arguments
        self.riskLevel = riskLevel
    }
}
