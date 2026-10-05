import AppKit
import os

private let logger = Logger(subsystem: "io.github.satis-ku.eyelid", category: "HUD")

/// What the notch shows after a volume or brightness key.
struct HUDEvent: Equatable, Sendable {
    enum Kind: Sendable {
        case volume
        case brightness
    }

    var kind: Kind
    var level: Float
    var isMuted = false
    /// The output device's icon, for volume. `.speaker` draws waves that follow the level.
    var deviceIcon: DeviceIcon = .speaker
    /// For AirPods with one earbud in: that earbud, so the icon shows what's in use.
    var earbud: HeadphonesBattery.Earbud?

    var symbolName: String {
        switch kind {
        case .volume:
            if deviceIcon != .speaker {
                earbud.flatMap(deviceIcon.earbudSymbolName) ?? deviceIcon.availableSymbolName
            }
            else if isMuted || level == 0 { "speaker.slash.fill" }
            else if level < 1 / 3 { "speaker.wave.1.fill" }
            else if level < 2 / 3 { "speaker.wave.2.fill" }
            else { "speaker.wave.3.fill" }
        case .brightness:
            level < 0.5 ? "sun.min.fill" : "sun.max.fill"
        }
    }

    /// Device icons have no muted variant, so they dim instead.
    var dimsIcon: Bool {
        kind == .volume && deviceIcon != .speaker && (isMuted || level == 0)
    }
}

/// Intercepts the volume and brightness keys: `MediaKeyTap` in the app, a stand-in in tests.
@MainActor
protocol KeyTap: AnyObject {
    var isRunning: Bool { get }
    /// Returns false without the Accessibility permission.
    func start() -> Bool
    func stop()
}

/// The Accessibility permission that the key tap needs: the system's in the app, a stand-in in tests.
struct AccessibilityAccess {
    var isGranted: @MainActor () -> Bool = { AXIsProcessTrusted() }
    /// Shows the system prompt that leads to the Accessibility list in System Settings.
    var request: @MainActor () -> Void = {
        // The key is kAXTrustedCheckOptionPrompt, which Swift 6 flags as a mutable global.
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }
}

/// Replaces the system volume and brightness HUD: handles the keys itself and reports every change.
@MainActor
final class HUDService {
    var onEvent: (@MainActor (HUDEvent) -> Void)?

    private let settings: AppSettings
    private let access: AccessibilityAccess
    private var tap: (any KeyTap)!
    private var accessTask: Task<Void, Never>?
    private var hasRequestedAccess = false

    init(
        settings: AppSettings,
        access: AccessibilityAccess = AccessibilityAccess(),
        makeTap: (@escaping @MainActor (MediaKeyPress) -> Bool) -> any KeyTap = { MediaKeyTap(handler: $0) }
    ) {
        self.settings = settings
        self.access = access
        tap = makeTap { [weak self] press in
            self?.handle(press) ?? false
        }
    }

    /// Starts handling the keys, or waits for the Accessibility permission first.
    func setEnabled(_ enabled: Bool) {
        accessTask?.cancel()
        accessTask = nil

        guard enabled else {
            tap.stop()
            return
        }

        if !tap.start() {
            logger.info("Waiting for Accessibility access to handle volume and brightness keys")
            // The ad hoc signature ties access to one build, so updates lose it too. Ask once per launch.
            if !hasRequestedAccess {
                hasRequestedAccess = true
                access.request()
            }
        }

        // Access is granted and taken away in System Settings, outside the app, so keep checking.
        accessTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled else { return }
                followAccess()
            }
        }
    }

    /// Starts handling the keys once Accessibility access is granted, and stops as soon as it's taken away:
    /// macOS keeps sending events to a tap that has lost access, and input across the Mac stalls while it waits.
    func followAccess() {
        let isGranted = access.isGranted()
        if tap.isRunning, !isGranted {
            tap.stop()
            logger.info("Accessibility access was taken away, leaving volume and brightness keys to macOS")
        } else if !tap.isRunning, isGranted, tap.start() {
            logger.info("Accessibility access granted, handling volume and brightness keys")
        }
    }

    private func handle(_ press: MediaKeyPress) -> Bool {
        guard !press.opensSystemSettings else { return false }

        switch press.key {
        case .volumeUp, .volumeDown, .mute:
            return handleVolume(press)
        case .brightnessUp, .brightnessDown:
            return handleBrightness(press)
        }
    }

    // A key up is handled exactly when its key down would be, so macOS never sees half a press.

    private func handleVolume(_ press: MediaKeyPress) -> Bool {
        // Devices without a settable volume stay with macOS, which shows that it can't change them.
        guard let (device, state) = SystemVolume.read() else { return false }
        guard press.isKeyDown else { return true }

        let new = state.after(press.key, fine: press.isFineStep)
        guard SystemVolume.apply(new, from: state, on: device) else { return false }

        let output = OutputDevice(audioDevice: device)
        let deviceIcon = output.map(settings.icon(for:)) ?? .speaker
        let earbud = output.flatMap(HeadphonesBattery.current(for:))?.singleEarbud
        logger.debug("Volume \(new.level, privacy: .public), muted: \(new.isMuted, privacy: .public), icon: \(deviceIcon.rawValue, privacy: .public)")
        onEvent?(HUDEvent(kind: .volume, level: new.level, isMuted: new.isMuted, deviceIcon: deviceIcon, earbud: earbud))
        return true
    }

    private func handleBrightness(_ press: MediaKeyPress) -> Bool {
        guard let display = DisplayBrightness.builtInDisplay,
              let level = DisplayBrightness.level(of: display)
        else { return false }
        guard press.isKeyDown else { return true }

        let new = LevelStep.next(from: level, up: press.key == .brightnessUp, fine: press.isFineStep)
        guard DisplayBrightness.setLevel(new, of: display) else { return false }

        logger.debug("Brightness \(new, privacy: .public)")
        onEvent?(HUDEvent(kind: .brightness, level: new))
        return true
    }
}
