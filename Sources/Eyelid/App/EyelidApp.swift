import SwiftUI

@main
struct EyelidApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Eyelid", systemImage: "eye") {
            MenuBarMenu()
        }

        Settings {
            SettingsView(
                settings: appDelegate.settings,
                shelf: appDelegate.shelf,
                clipboard: appDelegate.clipboard,
                clipboardShortcut: appDelegate.clipboardShortcut
            )
        }
    }
}

/// Eyelid has no Dock icon, so the menu bar item is the way to reach Settings and to quit.
private struct MenuBarMenu: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings…") {
            // Without a Dock icon the app is never active on its own, and Settings would open behind other windows.
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit Eyelid") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
