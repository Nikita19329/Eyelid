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

    /// AirPods report their charge a moment after connecting. Ask again until they have.
    private static let batteryDelays: [Duration] = [.seconds(1.5), .seconds(2.5)]

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
        onEvent?(event)

        batteryTask?.cancel()
        batteryTask = Task { [weak self] in
            for delay in Self.batteryDelays {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                if let battery = await Self.readBattery(of: device.name) {
                    event.battery = battery
                    self?.onEvent?(event)
                    return
                }
            }
        }
    }

    /// Asks `system_profiler`, which knows the charge of AirPods and Beats without the Bluetooth permission.
    nonisolated private static func readBattery(of deviceName: String) async -> HeadphonesBattery? {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(filePath: "/usr/sbin/system_profiler")
            process.arguments = ["SPBluetoothDataType", "-json"]
            process.environment = ["PATH": "/usr/bin:/bin"]
            let output = Pipe()
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
            } catch {
                logger.error("Could not run system_profiler: \(error.localizedDescription, privacy: .public)")
                return nil
            }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return HeadphonesBattery(systemProfilerJSON: data, deviceName: deviceName)
        }.value
    }
}
