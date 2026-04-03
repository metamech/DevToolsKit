import Foundation
import Testing
@testable import DevToolsKitProcess

@Suite("AsyncSemaphore")
struct AsyncSemaphoreTests {

    @Test("Allows up to maxConcurrent operations")
    func concurrencyLimit() async {
        let semaphore = AsyncSemaphore(maxConcurrent: 2)
        let counter = LockedCounter()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<4 {
                group.addTask {
                    await semaphore.withSlot {
                        counter.increment()
                        let current = counter.value
                        #expect(current <= 2, "Should never exceed maxConcurrent")
                        try? await Task.sleep(for: .milliseconds(50))
                        counter.decrement()
                    }
                }
            }
        }
    }

    @Test("Returns body result")
    func returnsResult() async {
        let semaphore = AsyncSemaphore(maxConcurrent: 1)
        let result = await semaphore.withSlot { 42 }
        #expect(result == 42)
    }

    @Test("Rethrows errors from body")
    func rethrowsErrors() async {
        let semaphore = AsyncSemaphore(maxConcurrent: 1)
        do {
            _ = try await semaphore.withSlot { throw TestError.expected }
            Issue.record("Should have thrown")
        } catch {
            #expect(error is TestError)
        }
    }

    @Test("Reports activeCount and waitingCount")
    func counters() async {
        let semaphore = AsyncSemaphore(maxConcurrent: 1)
        let initial = await semaphore.activeCount
        #expect(initial == 0)
        let waiting = await semaphore.waitingCount
        #expect(waiting == 0)
    }

    @Test("FIFO ordering of waiters")
    func fifoOrdering() async {
        let semaphore = AsyncSemaphore(maxConcurrent: 1)
        let order = LockedArray()

        // Acquire the single slot to block subsequent callers
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await semaphore.withSlot {
                    // Hold the slot while others queue up
                    try? await Task.sleep(for: .milliseconds(100))
                    order.append(0)
                }
            }

            // Give time for the first task to acquire
            try? await Task.sleep(for: .milliseconds(20))

            for i in 1...3 {
                let idx = i
                group.addTask {
                    await semaphore.withSlot {
                        order.append(idx)
                    }
                }
                // Stagger to ensure FIFO queue order
                try? await Task.sleep(for: .milliseconds(10))
            }
        }

        let values = order.values
        #expect(values.first == 0, "First task should complete first")
        // Subsequent tasks should be in FIFO order
        #expect(values.dropFirst().elementsEqual([1, 2, 3]))
    }
}

// MARK: - Test Helpers

private enum TestError: Error {
    case expected
}

private final class LockedCounter: @unchecked Sendable {
    private var _value = 0
    private let lock = NSLock()

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func increment() {
        lock.lock()
        _value += 1
        lock.unlock()
    }

    func decrement() {
        lock.lock()
        _value -= 1
        lock.unlock()
    }
}

private final class LockedArray: @unchecked Sendable {
    private var _values: [Int] = []
    private let lock = NSLock()

    var values: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return _values
    }

    func append(_ value: Int) {
        lock.lock()
        _values.append(value)
        lock.unlock()
    }
}
