import Foundation
import IOKit.ps
import Observation

/// Keeps `state` in sync with the internal battery and reports plugging in, unplugging and low charge.
@MainActor
@Observable
final class BatteryService {
    /// Nil on Macs without a battery.
    private(set) var state: BatteryState?

    @ObservationIgnored var onEvent: (@MainActor (BatteryEvent) -> Void)?
    @ObservationIgnored private var runLoopSource: CFRunLoopSource?

    func start() {
        guard runLoopSource == nil else { return }
        state = Self.readState()

        // The service lives as long as the app, so the callback can hold it unretained.
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let service = Unmanaged<BatteryService>.fromOpaque(context).takeUnretainedValue()
            // IOKit calls back on the run loop the source was added to: the main one.
            MainActor.assumeIsolated {
                service.update()
            }
        }, context)?.takeRetainedValue()
        else { return }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        runLoopSource = source
    }

    private func update() {
        guard let new = Self.readState() else {
            state = nil
            return
        }
        let event = BatteryEvent.between(state, and: new)
        state = new
        if let event {
            onEvent?(event)
        }
    }

    private static func readState() -> BatteryState? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        return sources.lazy
            .compactMap { IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any] }
            .compactMap(BatteryState.init(description:))
            .first
    }
}
