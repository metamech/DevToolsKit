import Testing
@testable import DevToolsKit

@Suite("LockedValue")
struct LockedValueTests {

    @Test("Stores and retrieves initial value")
    func initialValue() {
        let locked = LockedValue(42)
        #expect(locked.value == 42)
    }

    @Test("Supports value mutation")
    func mutation() {
        let locked = LockedValue("hello")
        locked.value = "world"
        #expect(locked.value == "world")
    }

    @Test("withLock transforms value atomically")
    func withLockTransform() {
        let locked = LockedValue(10)
        let result = locked.withLock { value -> Int in
            value += 5
            return value
        }
        #expect(result == 15)
        #expect(locked.value == 15)
    }

    @Test("Concurrent access does not corrupt state")
    func concurrentSafety() async {
        let locked = LockedValue(0)
        let iterations = 1000

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    locked.withLock { $0 += 1 }
                }
            }
        }

        #expect(locked.value == iterations)
    }

    @Test("Works with optional types")
    func optionalType() {
        let locked = LockedValue<String?>(nil)
        #expect(locked.value == nil)
        locked.value = "present"
        #expect(locked.value == "present")
    }

    @Test("Works with collection types")
    func collectionType() {
        let locked = LockedValue<[Int]>([])
        locked.withLock { $0.append(1) }
        locked.withLock { $0.append(2) }
        #expect(locked.value == [1, 2])
    }
}
