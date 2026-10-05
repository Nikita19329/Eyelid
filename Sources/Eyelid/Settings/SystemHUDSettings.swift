import AppKit
import SwiftUI

/// The volume and brightness toggle, plus what's missing while Accessibility access isn't granted.
struct SystemHUDSettings: View {
    @Bindable var settings: AppSettings
    @State private var isTrusted = AXIsProcessTrusted()

    var body: some View {
        Toggle(isOn: $settings.replacesSystemHUD) {
            Text("Volume and brightness")
            Text("Shows volume and brightness changes next to the notch instead of the system HUD. Eyelid needs Accessibility access to handle the keys.")
        }
        .onChange(of: settings.replacesSystemHUD) { _, isOn in
            if isOn, !AXIsProcessTrusted() {
                // Shows the system prompt that leads to Privacy & Security → Accessibility.
                // The key is kAXTrustedCheckOptionPrompt, which Swift 6 flags as a mutable global.
                AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            }
        }
        // Access is granted in System Settings, so keep checking while this window is open.
        .task {
            while !Task.isCancelled {
                isTrusted = AXIsProcessTrusted()
                try? await Task.sleep(for: .seconds(1))
            }
        }

        if settings.replacesSystemHUD, !isTrusted {
            LabeledContent("Allow Eyelid in Accessibility to finish.") {
                Button("Open Accessibility") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
            .foregroundStyle(.secondary)
        }
    }
}
