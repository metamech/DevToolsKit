import Foundation

/// Protocol for handling permission requests.
///
/// Implement this protocol to provide custom permission UI or logic.
///
/// Since 0.4.0
public protocol PermissionHandler: Sendable {
    /// Request permission to execute an operation.
    /// - Parameter request: The permission request.
    /// - Returns: The user's response.
    func requestPermission(_ request: PermissionRequest) async -> PermissionResponse
}

/// Permission handler that auto-approves all requests.
///
/// Useful for testing or trusted environments where all operations should be allowed.
///
/// Since 0.4.0
public struct AutoApprovePermissionHandler: PermissionHandler {
    /// Creates a new auto-approve handler.
    public init() {}

    public func requestPermission(_ request: PermissionRequest) async -> PermissionResponse {
        .allow
    }
}
