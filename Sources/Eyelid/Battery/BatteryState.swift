import Foundation
import IOKit.ps

/// The internal battery, as IOKit's power source description reports it.
struct BatteryState: Equatable, Sendable {
    /// Charge in percent, 0–100.
    var level: Int
    /// Connected to power. The battery may still not charge, for example when it's full or
    /// Optimized Battery Charging holds it at 80%.
    var isPluggedIn: Bool
    var isCharging: Bool

    init(level: Int, isPluggedIn: Bool, isCharging: Bool) {
        self.level = level
        self.isPluggedIn = isPluggedIn
        self.isCharging = isCharging
    }

    /// Returns nil for anything but an internal battery, such as a UPS.
    init?(description: [String: Any]) {
        guard description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
              let current = description[kIOPSCurrentCapacityKey] as? Int,
              let maximum = description[kIOPSMaxCapacityKey] as? Int,
              maximum > 0
        else { return nil }

        let percent = Int((Double(current) / Double(maximum) * 100).rounded())
        self.init(
            level: min(max(percent, 0), 100),
            isPluggedIn: description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
            isCharging: description[kIOPSIsChargingKey] as? Bool ?? false
        )
    }
}

/// A battery change worth showing next to the notch.
enum BatteryEvent: Equatable, Sendable {
    case pluggedIn(BatteryState)
    case unplugged(BatteryState)
    case low(BatteryState)

    /// Levels at which a battery running without a charger gets a warning.
    static let lowLevels = [20, 10]

    var state: BatteryState {
        switch self {
        case .pluggedIn(let state), .unplugged(let state), .low(let state):
            state
        }
    }

    /// The event for the battery going from `old` to `new`, if there is one.
    static func between(_ old: BatteryState?, and new: BatteryState) -> BatteryEvent? {
        // The first reading at launch is not news.
        guard let old else { return nil }

        if new.isPluggedIn != old.isPluggedIn {
            return new.isPluggedIn ? .pluggedIn(new) : .unplugged(new)
        }
        // One warning even if the level skips past several thresholds, for example across sleep.
        if !new.isPluggedIn, lowLevels.contains(where: { old.level > $0 && new.level <= $0 }) {
            return .low(new)
        }
        return nil
    }
}
