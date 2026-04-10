import Foundation
import os

/// Collects metric entries in a thread-safe buffer and flushes them
/// to a `MetricsStorage` on a coalesced schedule, eliminating per-emit
/// Task creation overhead.
final class MetricsBatcher: Sendable {
    private let buffer: OSAllocatedUnfairLock<[MetricEntry]>
    private let storage: any MetricsStorage
    private let flushThreshold: Int
    private let flushInterval: Duration
    private let timer: OSAllocatedUnfairLock<DispatchSourceTimer?>

    init(
        storage: any MetricsStorage,
        flushInterval: Duration = .milliseconds(250),
        flushThreshold: Int = 100
    ) {
        self.storage = storage
        self.flushInterval = flushInterval
        self.flushThreshold = flushThreshold
        self.buffer = OSAllocatedUnfairLock(initialState: [])
        self.timer = OSAllocatedUnfairLock(initialState: nil)
    }

    func append(_ entry: MetricEntry) {
        let shouldFlush = buffer.withLock { buf -> Bool in
            buf.append(entry)
            return buf.count >= flushThreshold
        }
        if shouldFlush {
            flush()
        }
    }

    func flush() {
        let entries = buffer.withLock { buf -> [MetricEntry] in
            guard !buf.isEmpty else { return [] }
            let drained = buf
            buf.removeAll(keepingCapacity: true)
            return drained
        }
        guard !entries.isEmpty else { return }
        Task { @MainActor in
            storage.record(entries)
        }
    }

    func start() {
        let queue = DispatchQueue(label: "com.devtoolskit.metrics.batcher", qos: .utility)
        let source = DispatchSource.makeTimerSource(queue: queue)

        // Convert Duration to nanoseconds for DispatchSourceTimer.
        // Duration.components gives (seconds: Int64, attoseconds: Int64).
        // 1 nanosecond = 1_000_000_000 attoseconds.
        let components = flushInterval.components
        let totalNanos = components.seconds * 1_000_000_000
            + components.attoseconds / 1_000_000_000

        source.schedule(
            deadline: .now() + .nanoseconds(Int(totalNanos)),
            repeating: .nanoseconds(Int(totalNanos)),
            leeway: .milliseconds(50)
        )
        source.setEventHandler { [weak self] in
            self?.flush()
        }

        timer.withLock { t in
            t?.cancel()
            t = source
        }
        source.resume()
    }

    func stop() {
        timer.withLock { t in
            t?.cancel()
            t = nil
        }
        flush()
    }
}
