import AppKit

/// Sends files from the shelf to other devices.
@MainActor
enum ShelfSharing {
    /// Opens the AirDrop window with the files, to pick who gets them.
    static func airDrop(_ urls: [URL]) {
        guard let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: urls) else {
            NSSound.beep()
            return
        }
        // The window is Eyelid's, and Eyelid is never in front on its own: it would open behind other apps.
        NSApp.activate()
        service.perform(withItems: urls)
    }
}
