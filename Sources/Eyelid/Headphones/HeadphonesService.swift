import CoreAudio
import Foundation
import os

private let logger = Logger(subsystem: "io.github.nikita19329.eyelid", category: "Headphones")

/// Notices Bluetooth headphones connecting, and reports their battery once macOS knows it.
@MainActor
final class HeadphonesService {
    var onEvent: (@MainActor (HeadphonesEvent) -> Void)?

    private let settings: AppSettings
    /// The Bluetooth outputs seen so far, so only a new one counts as connecting.
    private var knownDevices: Set<String> = []
    private var listener: AudioObjectPropertyListenerBlock?
    private var batteryTask: Task<Void, Never>?

    /// AirPods report their charge a moment after connecting, if macOS doesn't know it already. Until they do, the
    /// notch waits and looks again, so the icon and the charge show up together.
    private static let batteryPollInterval: Duration = .milliseconds(200)
    /// Apple headphones that haven't reported a charge by then show up with their icon alone.
    private static let batteryWait: Duration = .seconds(3)

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        knownDevices = Set(OutputDevice.all().filter { $0.transport == .bluetooth }.map(\.id))

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
            self?.onEvent?(event)
        }
    }
}
