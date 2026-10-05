import CoreAudio
import Foundation
import notify
import os

private let logger = Logger(subsystem: "io.github.nikita19329.eyelid", category: "Headphones")

/// Notices Bluetooth headphones connecting, and earbuds going in or out of the case while they're connected.
@MainActor
final class HeadphonesService {
    var onEvent: (@MainActor (HeadphonesEvent) -> Void)?

    private let settings: AppSettings
    /// The Bluetooth outputs seen so far, so only a new one counts as connecting.
    private var knownDevices: Set<String> = []
    private var listener: AudioObjectPropertyListenerBlock?
    private var batteryTask: Task<Void, Never>?
    /// Connected Apple and Beats headphones, which report which earbuds are out of the case.
    private var appleHeadphones: [OutputDevice] = []
    /// The earbuds out of the case at the last look, by device. Missing until the connection has shown.
    private var earbudsInUse: [String: Set<HeadphonesBattery.Earbud>] = [:]
    private var watchTask: Task<Void, Never>?
    private var notifyTokens: [Int32] = []

    /// AirPods report their charge a moment after connecting, if macOS doesn't know it already. Until they do, the
    /// notch waits and looks again, so the icon and the charge show up together.
    private static let batteryPollInterval: Duration = .milliseconds(200)
    /// Apple headphones that haven't reported a charge by then show up with their icon alone.
    private static let batteryWait: Duration = .seconds(3)
    /// macOS posts these when an accessory's power sources change, such as an earbud going in or out of the case.
    /// The names are IOKit's, from its private headers.
    private static let accessoryNotifications = [
        "com.apple.system.accpowersources.attach",
        "com.apple.system.accpowersources.timeremaining",
    ]
    /// In case a notification goes missing, a look every so often while headphones are connected. Each look is a
    /// local IOKit call.
    private static let earbudsInterval: Duration = .seconds(2)

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        for name in Self.accessoryNotifications {
            var token: Int32 = 0
            let status = notify_register_dispatch(name, &token, .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.checkEarbuds()
                }
            }
            if status == NOTIFY_STATUS_OK {
                notifyTokens.append(token)
            }
        }

        let devices = OutputDevice.all()
        knownDevices = Set(devices.filter { $0.transport == .bluetooth }.map(\.id))
        followAppleHeadphones(in: devices)
        for device in appleHeadphones {
            earbudsInUse[device.id] = HeadphonesBattery.current(for: device)?.earbudsInUse
        }

        var address = AudioProperty.address(kAudioHardwarePropertyDevices)
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            // Runs on the main queue, as passed below.
            MainActor.assumeIsolated {
                self?.devicesChanged()
            }
        }
        let status = AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
        if status == noErr {
            self.listener = listener
        } else {
            logger.error("Could not watch audio devices: \(status, privacy: .public)")
        }
    }

    /// Bluetooth outputs in `devices` that weren't in `known`.
    nonisolated static func newBluetoothDevices(in devices: [OutputDevice], known: Set<String>) -> [OutputDevice] {
        devices.filter { $0.transport == .bluetooth && !known.contains($0.id) }
    }

    private func devicesChanged() {
        let devices = OutputDevice.all()
        let connected = Self.newBluetoothDevices(in: devices, known: knownDevices)
        knownDevices = Set(devices.filter { $0.transport == .bluetooth }.map(\.id))
        followAppleHeadphones(in: devices)

        guard settings.headphonesActivityEnabled, let device = connected.first else { return }
        logger.debug("Connected: \(device.name, privacy: .public)")

        var event = HeadphonesEvent(deviceID: device.id, name: device.name, icon: settings.icon(for: device))
        batteryTask?.cancel()

        // Only Apple and Beats headphones report their charge, so others show up right away.
        guard let productID = device.appleProductID else {
            onEvent?(event)
            return
        }

        batteryTask = Task { [weak self] in
            let deadline = ContinuousClock.now + Self.batteryWait
            while ContinuousClock.now < deadline, !Task.isCancelled {
                event.battery = HeadphonesBattery(
                    powerSources: AccessoryPowerSources.descriptions(),
                    deviceName: device.name,
                    productID: productID
                )
                if event.battery?.isInUse == true { break }
                try? await Task.sleep(for: Self.batteryPollInterval)
            }
            guard !Task.isCancelled else { return }
            logger.debug("Battery: \(String(describing: event.battery), privacy: .public)")
            self?.earbudsInUse[device.id] = event.battery?.earbudsInUse ?? []
            self?.onEvent?(event)
        }
    }

    // MARK: - Earbuds going in and out

    /// Watches the connected Apple and Beats headphones, and stops once there are none.
    private func followAppleHeadphones(in devices: [OutputDevice]) {
        appleHeadphones = devices.filter { $0.transport == .bluetooth && $0.appleProductID != nil }
        let connected = Set(appleHeadphones.map(\.id))
        earbudsInUse = earbudsInUse.filter { connected.contains($0.key) }

        guard !appleHeadphones.isEmpty else {
            watchTask?.cancel()
            watchTask = nil
            return
        }
        guard watchTask == nil else { return }
        watchTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.earbudsInterval)
                self?.checkEarbuds()
            }
        }
    }

    /// Shows the headphones again when an earbud goes in or out of the case, so the notch shows what's in use.
    private func checkEarbuds() {
        for device in appleHeadphones {
            guard let previous = earbudsInUse[device.id],
                  let battery = HeadphonesBattery.current(for: device)
            else { continue }
            let current = battery.earbudsInUse
            earbudsInUse[device.id] = current
            guard Self.isWorthShowing(from: previous, to: current), settings.headphonesActivityEnabled else { continue }

            logger.debug("Earbuds in use: \(current.count, privacy: .public)")
            onEvent?(HeadphonesEvent(deviceID: device.id, name: device.name, icon: settings.icon(for: device), battery: battery))
        }
    }

    /// One earbud in, the second one joining, or one leaving. Not both going back in the case, which disconnects them.
    nonisolated static func isWorthShowing(
        from previous: Set<HeadphonesBattery.Earbud>,
        to current: Set<HeadphonesBattery.Earbud>
    ) -> Bool {
        current != previous && !current.isEmpty
    }
}
