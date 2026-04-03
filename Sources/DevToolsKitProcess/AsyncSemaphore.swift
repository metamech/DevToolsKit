import Foundation

/// A generic async semaphore that limits concurrent access to a shared resource.
///
/// Uses a FIFO continuation queue to ensure fair ordering. Callers acquire a slot
/// before proceeding and release it when done, preventing resource exhaustion
/// from unbounded concurrent operations.
///
/// ```swift
/// let semaphore = AsyncSemaphore(maxConcurrent: 4)
/// let result = await semaphore.withSlot {
///     await performExpensiveWork()
/// }
/// ```
///
/// - Since: 0.9.0
public actor AsyncSemaphore {

    private let maxConcurrent: Int
    private var active: Int = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// Creates a semaphore with the given concurrency limit.
    ///
    /// - Parameter maxConcurrent: The maximum number of concurrent operations allowed.
    ///   Must be greater than zero.
    public init(maxConcurrent: Int) {
        precondition(maxConcurrent > 0, "maxConcurrent must be greater than zero")
        self.maxConcurrent = maxConcurrent
    }

    /// The number of currently active operations.
    public var activeCount: Int { active }

    /// The number of operations waiting for a slot.
    public var waitingCount: Int { waiters.count }

    /// Execute `body` with an acquired slot, releasing the slot when done.
    ///
    /// If all slots are occupied, the caller suspends until a slot becomes available.
    /// Slots are granted in FIFO order.
    ///
    /// - Parameter body: The async closure to execute within the semaphore slot.
    /// - Returns: The value returned by `body`.
    /// - Throws: Rethrows any error thrown by `body`.
    public func withSlot<T: Sendable>(_ body: @Sendable () async throws -> T) async rethrows -> T {
        await acquireSlot()
        do {
            let result = try await body()
            releaseSlot()
            return result
        } catch {
            releaseSlot()
            throw error
        }
    }

    private func acquireSlot() async {
        if active < maxConcurrent {
            active += 1
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waiters.append(continuation)
        }
    }

    private func releaseSlot() {
        if !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.resume()
        } else {
            active -= 1
        }
    }
}
