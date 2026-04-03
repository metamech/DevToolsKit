import Foundation
import os

/// A thread-safe container using `OSAllocatedUnfairLock` for synchronous access.
///
/// Provides a simple way to protect a value for concurrent read/write access
/// from nonisolated synchronous contexts where `async` is not available.
///
/// ```swift
/// let counter = LockedValue(0)
/// counter.value += 1
/// print(counter.value)
/// ```
///
/// - Since: 0.9.0
public final class LockedValue<T: Sendable>: @unchecked Sendable {
    private var _value: T
    private let _lock = OSAllocatedUnfairLock()

    /// Creates a locked value container with the given initial value.
    ///
    /// - Parameter value: The initial value to store.
    public init(_ value: T) {
        _value = value
    }

    /// The current value, protected by an unfair lock.
    ///
    /// Both reads and writes are serialized through the lock.
    public var value: T {
        get {
            _lock.withLock { _value }
        }
        set {
            _lock.withLock { _value = newValue }
        }
    }

    /// Atomically transforms the value using the given closure.
    ///
    /// - Parameter transform: A closure that receives the current value and returns a new value.
    /// - Returns: The value returned by the closure.
    @discardableResult
    public func withLock<R: Sendable>(_ transform: @Sendable (inout T) -> R) -> R {
        _lock.withLock {
            transform(&_value)
        }
    }
}
