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

    /// Creates a factory backed by the given storage.
    ///
    /// - Parameter storage: The storage backend to record metrics into.
    public init(storage: any MetricsStorage) {
        self.storage = storage
    }

    public func makeCounter(label: String, dimensions: [(String, String)]) -> CounterHandler {
        DevToolsCounterHandler(label: label, dimensions: dimensions, storage: storage)
    }

    public func makeFloatingPointCounter(
        label: String,
        dimensions: [(String, String)]
    ) -> FloatingPointCounterHandler {
        DevToolsFloatingPointCounterHandler(label: label, dimensions: dimensions, storage: storage)
    }

    public func makeMeter(label: String, dimensions: [(String, String)]) -> MeterHandler {
        DevToolsMeterHandler(label: label, dimensions: dimensions, storage: storage)
    }

    public func makeRecorder(
        label: String,
        dimensions: [(String, String)],
        aggregate: Bool
    ) -> RecorderHandler {
        DevToolsRecorderHandler(label: label, dimensions: dimensions, storage: storage)
    }

    public func makeTimer(label: String, dimensions: [(String, String)]) -> TimerHandler {
        DevToolsTimerHandler(label: label, dimensions: dimensions, storage: storage)
    }

    public func destroyCounter(_ handler: CounterHandler) {}
    public func destroyFloatingPointCounter(_ handler: FloatingPointCounterHandler) {}
    public func destroyMeter(_ handler: MeterHandler) {}
    public func destroyRecorder(_ handler: RecorderHandler) {}
    public func destroyTimer(_ handler: TimerHandler) {}
}
