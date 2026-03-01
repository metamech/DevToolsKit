import Foundation
import SwiftUI

/// Observable store for permission audit entries.
///
/// Since 0.4.0
@MainActor
@Observable
public final class PermissionAuditStore: Sendable {
    /// All audit entries, newest first.
    public private(set) var entries: [PermissionAuditEntry] = []

    /// Maximum number of entries to retain.
    public let maxEntries: Int

    /// Creates a new audit store.
    /// - Parameter maxEntries: Maximum number of entries to retain (default: 1000).
    public init(maxEntries: Int = 1000) {
        self.maxEntries = maxEntries
    }

    /// Record a permission decision.
    /// - Parameter entry: The audit entry to record.
    public func record(_ entry: PermissionAuditEntry) {
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries.removeLast()
        }
    }

    /// Clear all audit entries.
    public func clear() {
        entries.removeAll()
    }
}
