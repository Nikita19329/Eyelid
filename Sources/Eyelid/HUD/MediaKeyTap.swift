import AppKit

/// Intercepts volume and brightness keys with an event tap, which needs the Accessibility permission.
/// Presses that `handler` returns true for never reach macOS, so the system HUD doesn't appear.
@MainActor
final class MediaKeyTap: KeyTap {
    private let handler: @MainActor (MediaKeyPress) -> Bool
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(handler: @escaping @MainActor (MediaKeyPress) -> Bool) {
        self.handler = handler
    }

    var isRunning: Bool { tap != nil }

    /// Returns false without the Accessibility permission.
    func start() -> Bool {
        guard tap == nil else { return true }

        // NX_SYSDEFINED: media keys arrive as system-defined events, not key events.
        let systemDefined: UInt32 = 14
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << systemDefined),
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let tap = Unmanaged<MediaKeyTap>.fromOpaque(context).takeUnretainedValue()
                // The tap's run loop source is on the main run loop. Only the Bool leaves the main actor,
                // since CGEvent isn't Sendable.
                let consumed = MainActor.assumeIsolated {
                    tap.consumes(type, event)
                }
                return consumed ? nil : Unmanaged.passUnretained(event)
            },
            // Unretained: the owner calls stop() before letting go, which invalidates the tap.
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        runLoopSource = source
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CFMachPortInvalidate(tap)
        self.tap = nil
        runLoopSource = nil
    }

    /// Whether the event is a press `handler` took care of, which then never reaches macOS.
    private func consumes(_ type: CGEventType, _ event: CGEvent) -> Bool {
        // macOS turns a tap off when a callback takes too long, and on some user input. Turn it back on, unless
        // Accessibility access is gone: then the tap would stall input until HUDService removes it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap, AXIsProcessTrusted() {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return false
        }

        guard let nsEvent = NSEvent(cgEvent: event),
              nsEvent.type == .systemDefined,
              nsEvent.subtype.rawValue == MediaKeyPress.auxControlButtonsSubtype,
              let press = MediaKeyPress(data1: nsEvent.data1, modifierFlags: nsEvent.modifierFlags)
        else { return false }

        return handler(press)
    }
}
