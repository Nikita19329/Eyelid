import AppKit
import Carbon.HIToolbox
import os

private let logger = Logger(subsystem: "io.github.satis-ku.eyelid", category: "Clipboard")

/// Pastes into the app in front by pressing ⌘V for it, which needs Accessibility access.
@MainActor
enum Paster {
    private static var hasRequestedAccess = false

    /// Presses ⌘V once the app in front has the keyboard back. Without access, asks for it once per launch,
    /// and the copy stays on the pasteboard for the user to paste.
    static func paste(access: AccessibilityAccess = AccessibilityAccess()) {
        guard access.isGranted() else {
            logger.info("Can't paste without Accessibility access, the copy is on the pasteboard")
            if !hasRequestedAccess {
                hasRequestedAccess = true
                access.request()
            }
            return
        }

        Task {
            // The panel hands the keyboard back as it closes. A moment later, ⌘V reaches the app in front.
            try? await Task.sleep(for: .milliseconds(120))
            let source = CGEventSource(stateID: .combinedSessionState)
            for isDown in [true, false] {
                let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: isDown)
                event?.flags = .maskCommand
                event?.post(tap: .cgSessionEventTap)
            }
        }
    }
}
