import SwiftUI

@main
struct EyelidApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Eyelid has no Dock icon, so the menu bar item is the way to quit it.
        MenuBarExtra("Eyelid", systemImage: "eye") {
            Button("Quit Eyelid") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
