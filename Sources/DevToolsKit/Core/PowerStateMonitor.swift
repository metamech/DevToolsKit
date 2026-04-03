#if os(macOS)
import Foundation
import IOKit.ps
import Observation

/// Monitors the system power source (AC vs battery) using IOKit notifications.
///
/// Zero-polling: registers a run loop callback via `IOPSNotificationCreateRunLoopSource`
/// that fires only when the power source changes. macOS only.
///
/// ```swift
/// let monitor = PowerStateMonitor()
/// monitor.onSourceChanged = { source in
///     print("Now on \(source.rawValue)")
/// }
/// monitor.start()
/// ```
///
/// - Since: 0.9.0
@MainActor @Observable
public final class PowerStateMonitor {

    /// The system power source.
    public enum PowerSource: String, Sendable {
        /// Connected to AC power.
        case ac
        /// Running on battery.
        case battery
        /// Power source could not be determined.
        case unknown
    }

    /// The current power source.
    public private(set) var currentSource: PowerSource = .unknown

    /// Callback invoked on MainActor when the power source changes.
    public var onSourceChanged: (@MainActor (PowerSource) -> Void)?

    private var runLoopSource: CFRunLoopSource?

    // MARK: - Lifecycle

    /// Creates a power state monitor.
    public init() {}

    /// Starts monitoring power source changes.
    ///
    /// Registers an IOKit run loop source on the main run loop. Reads the
    /// initial power state immediately. Safe to call multiple times — subsequent
    /// calls are no-ops if already started.
    public func start() {
        guard runLoopSource == nil else { return }

        let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<PowerStateMonitor>.fromOpaque(context).takeUnretainedValue()
            let source = PowerStateMonitor.detectPowerSource()
            Task { @MainActor in
                let previous = monitor.currentSource
                monitor.currentSource = source
                if source != previous {
                    monitor.onSourceChanged?(source)
                }
            }
        }, Unmanaged.passUnretained(self).toOpaque())

        if let source = source?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }

        // Read initial state
        currentSource = Self.detectPowerSource()
    }

    /// Stops monitoring power source changes.
    ///
    /// Removes the IOKit run loop source. Safe to call if not started.
    public func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
    }

    // MARK: - Detection

    /// Detect the current power source by querying IOKit.
    ///
    /// This is a synchronous, nonisolated query that can be called from any context.
    ///
    /// - Returns: The detected power source.
    nonisolated public static func detectPowerSource() -> PowerSource {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            return .unknown
        }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any] else {
                continue
            }
            if let powerSource = desc[kIOPSPowerSourceStateKey] as? String {
                if powerSource == kIOPSACPowerValue {
                    return .ac
                } else if powerSource == kIOPSBatteryPowerValue {
                    return .battery
                }
            }
        }

        return .unknown
    }
}
#endif
