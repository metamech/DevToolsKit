import CoreMetrics

/// A swift-metrics factory that routes all metric recordings to a ``MetricsStorage``.
///
/// Usage:
/// ```swift
/// let store = InMemoryMetricsStorage()
/// MetricsSystem.bootstrap(DevToolsMetricsFactory(storage: store))
/// ```
public final class DevToolsMetricsFactory: MetricsFactory, @unchecked Sendable {
    private let storage: any MetricsStorage
    private let batcher: MetricsBatcher

    /// Creates a factory backed by the given storage.
    ///
    /// - Parameter storage: The storage backend to record metrics into.
    public init(storage: any MetricsStorage) {
        self.storage = storage
        self.batcher = MetricsBatcher(storage: storage)
        self.batcher.start()
    }

    /// Stops the internal batcher timer and flushes any pending entries.
    public func stop() {
        batcher.stop()
    }

    public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        DevToolsCounterHandler(label: label, dimensions: dimensions, batcher: batcher)
    }

    public func makeFloatingPointCounter(
        label: String,
        dimensions: [(String, String)]
    ) -> FloatingPointCounterHandler {
        DevToolsFloatingPointCounterHandler(label: label, dimensions: dimensions, batcher: batcher)
    }

    public func makeMeter(label: String, dimensions: [(String, String)]) -> MeterHandler {
        DevToolsMeterHandler(label: label, dimensions: dimensions, batcher: batcher)
    }

    public func makeRecorder(
        label: String,
        dimensions: [(String, String)],
        aggregate: Bool
    ) -> RecorderHandler {
        DevToolsRecorderHandler(label: label, dimensions: dimensions, batcher: batcher)
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        DevToolsTimerHandler(label: label, dimensions: dimensions, batcher: batcher)
    }

    public func destroyCounter(_ handler: CounterHandler) {}
    public func destroyFloatingPointCounter(_ handler: FloatingPointCounterHandler) {}
    public func destroyMeter(_ handler: MeterHandler) {}
    public func destroyRecorder(_ handler: RecorderHandler) {}
    public func destroyTimer(_ handler: TimerHandler) {}
}
