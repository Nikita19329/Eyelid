import AppKit
import os

private let logger = Logger(subsystem: "io.github.nikita19329.eyelid", category: "HUD")

/// What the notch shows after a volume or brightness key.
struct HUDEvent: Equatable, Sendable {
    enum Kind: Sendable {
        case volume
        case brightness
    }

    var kind: Kind
    var level: Float
    var isMuted = false

    var symbolName: String {
        switch kind {
        case .volume:
            if isMuted || level == 0 { "speaker.slash.fill" }
            else if level < 1 / 3 { "speaker.wave.1.fill" }
            else if level < 2 / 3 { "speaker.wave.2.fill" }
            else { "speaker.wave.3.fill" }
        case .brightness:
            level < 0.5 ? "sun.min.fill" : "sun.max.fill"
        }
    }
}

/// Replaces the system volume and brightness HUD: handles the keys itself and reports every change.
@MainActor
final class HUDService {
    var onEvent: (@MainActor (HUDEvent) -> Void)?

    private var tap: MediaKeyTap!
    private var permissionTask: Task<Void, Never>?

    init() {
        tap = MediaKeyTap { [weak self] press in
            self?.handle(press) ?? false
        }
    }

    /// Starts handling the keys, or waits for the Accessibility permission first.
    func setEnabled(_ enabled: Bool) {
        permissionTask?.cancel()
        permissionTask = nil

        guard enabled else {
            tap.stop()
            return
        }
        guard !tap.start() else { return }

        // Access is granted in System Settings, outside the app, so check back until it is.
        logger.info("Waiting for Accessibility access to handle volume and brightness keys")
        permissionTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled else { return }
                if AXIsProcessTrusted(), tap.start() {
                    logger.info("Accessibility access granted, handling volume and brightness keys")
                    return
                }
            }
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

        logger.debug("Volume \(new.level, privacy: .public), muted: \(new.isMuted, privacy: .public)")
        onEvent?(HUDEvent(kind: .volume, level: new.level, isMuted: new.isMuted))
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
