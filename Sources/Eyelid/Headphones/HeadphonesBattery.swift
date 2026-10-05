import Foundation

/// The charge of wireless headphones, in percent: each earbud and the case for AirPods, one level for
/// over-ear headphones. Missing parts are nil.
struct HeadphonesBattery: Equatable, Sendable {
    var left: Int?
    var right: Int?
    var `case`: Int?
    var main: Int?

    /// The level to show first: the emptier earbud, since that's the one that runs out.
    var level: Int? {
        [left, right].compactMap(\.self).min() ?? main
    }
}

extension HeadphonesBattery {
    /// Reads the charge of a connected device from `system_profiler SPBluetoothDataType -json`, which macOS fills in
    /// for AirPods and Beats. Returns nil when the device isn't connected or reports no battery.
    init?(systemProfilerJSON data: Data, deviceName: String) {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let controllers = root["SPBluetoothDataType"] as? [[String: Any]]
        else { return nil }

        let connected = controllers
            .flatMap { $0["device_connected"] as? [[String: Any]] ?? [] }
            .compactMap { $0[deviceName] as? [String: Any] }
        guard let info = connected.first else { return nil }

        func percent(_ key: String) -> Int? {
            guard let value = info[key] as? String else { return nil }
            return Int(value.trimmingCharacters(in: CharacterSet(charactersIn: "% ")))
        }

        self.init(
            left: percent("device_batteryLevelLeft"),
            right: percent("device_batteryLevelRight"),
            case: percent("device_batteryLevelCase"),
            main: percent("device_batteryLevelMain")
        )
        guard level != nil || self.case != nil else { return nil }
    }
}

/// Headphones that just connected, shown next to the closed notch for a moment.
struct HeadphonesEvent: Equatable, Sendable {
    var deviceID: String
    var name: String
    var icon: DeviceIcon
    /// Arrives a moment after the connection, once macOS knows it, or never for headphones that don't report it.
    var battery: HeadphonesBattery?
}
