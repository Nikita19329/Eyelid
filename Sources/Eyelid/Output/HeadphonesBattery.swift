import Foundation
import IOKit.ps

/// The charge of wireless headphones, in percent: each earbud and the case for AirPods, one level for
/// over-ear headphones. Missing parts are nil.
struct HeadphonesBattery: Equatable, Sendable {
    enum Earbud: Equatable, Sendable {
        case left
        case right
    }

    var left: Int?
    var right: Int?
    var `case`: Int?
    var main: Int?
    /// An earbud in the case runs on the case's power, which is how macOS tells it apart from one in use.
    var leftIsInCase = false
    var rightIsInCase = false

    /// The level to show: the earbud in use, or the emptier one, since that's the one that runs out.
    var level: Int? {
        switch singleEarbud {
        case .left: left
        case .right: right
        case nil: [left, right].compactMap(\.self).min() ?? main
        }
    }

    /// Whether macOS already knows the headphones are out of the case. Right after connecting, it may still have both
    /// earbuds there from before.
    var isInUse: Bool {
        main != nil || (left != nil && !leftIsInCase) || (right != nil && !rightIsInCase)
    }

    /// The earbuds out of the case. Empty for over-ear headphones, which have none.
    var earbudsInUse: Set<Earbud> {
        var earbuds: Set<Earbud> = []
        if left != nil, !leftIsInCase { earbuds.insert(.left) }
        if right != nil, !rightIsInCase { earbuds.insert(.right) }
        return earbuds
    }

    /// The earbud in use when the other one stays in the case.
    var singleEarbud: Earbud? {
        let leftInUse = left != nil && !leftIsInCase
        let rightInUse = right != nil && !rightIsInCase
        switch (leftInUse, rightInUse) {
        case (true, false): return .left
        case (false, true): return .right
        default: return nil
        }
    }
}

extension HeadphonesBattery {
    /// Reads the charge of a device from accessory power sources, as `AccessoryPowerSources.descriptions()` returns
    /// them: one per earbud and one for the case, all named after the device. With both earbuds in, macOS lists a
    /// single combined one instead. Returns nil when there's none.
    init?(powerSources: [[String: Any]], deviceName: String, productID: Int?) {
        let parts = powerSources.filter { source in
            guard (source[kIOPSNameKey] as? String)?.hasPrefix(deviceName) == true else { return false }
            guard let productID else { return true }
            return source["Product ID"] as? Int == productID
        }
        guard !parts.isEmpty else { return nil }

        func charge(of source: [String: Any]) -> Int? {
            source[kIOPSCurrentCapacityKey] as? Int
        }
        func isOnCasePower(_ source: [String: Any]) -> Bool {
            source[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
        }

        self.init()
        for part in parts {
            switch part["Part Identifier"] as? String {
            case "Left":
                left = charge(of: part)
                leftIsInCase = isOnCasePower(part)
            case "Right":
                right = charge(of: part)
                rightIsInCase = isOnCasePower(part)
            case "Combined":
                left = charge(of: part)
                right = left
                leftIsInCase = isOnCasePower(part)
                rightIsInCase = leftIsInCase
            case "Case":
                self.case = charge(of: part)
            default:
                main = charge(of: part)
            }
        }
        guard level != nil || self.case != nil else { return nil }
    }
}

extension HeadphonesBattery {
    /// The charge of a connected output, if it's Apple or Beats headphones, which report it.
    static func current(for device: OutputDevice) -> HeadphonesBattery? {
        guard device.transport == .bluetooth, let productID = device.appleProductID else { return nil }
        return HeadphonesBattery(
            powerSources: AccessoryPowerSources.descriptions(),
            deviceName: device.name,
            productID: productID
        )
    }
}

/// The power sources of accessories such as AirPods and Beats, which macOS keeps for its Batteries widget. The public
/// IOKit call only lists the Mac's own battery, so this looks up the private one that lists accessories, the same way
/// `DisplayBrightness` uses DisplayServices.
enum AccessoryPowerSources {
    private typealias CopyPowerSourcesByType = @convention(c) (Int32) -> Unmanaged<CFTypeRef>?

    /// kIOPSSourceForAccessories in IOKit's private headers.
    private static let accessoriesType: Int32 = 4

    private static let copyPowerSourcesByType: CopyPowerSourcesByType? = {
        // RTLD_DEFAULT: IOKit is already loaded.
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "IOPSCopyPowerSourcesByType") else {
            return nil
        }
        return unsafeBitCast(symbol, to: CopyPowerSourcesByType.self)
    }()

    /// Whether this macOS still has the private call.
    static var isAvailable: Bool {
        copyPowerSourcesByType != nil
    }

    static func descriptions() -> [[String: Any]] {
        guard let copyPowerSourcesByType, let blob = copyPowerSourcesByType(accessoriesType)?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return [] }
        return list.compactMap { IOPSGetPowerSourceDescription(blob, $0)?.takeUnretainedValue() as? [String: Any] }
    }
}

/// Where sound just switched to, or the earbuds in use as they change, shown next to the closed notch for a moment.
struct OutputEvent: Equatable, Sendable {
    var deviceID: String
    var name: String
    var icon: DeviceIcon
    /// Known for AirPods and Beats, which report it to macOS.
    var battery: HeadphonesBattery?
    /// For outputs without a battery: their volume, so the notch shows where the sound went and how loud.
    var volume: SystemVolume.State?
}
