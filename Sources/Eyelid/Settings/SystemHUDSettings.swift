import AppKit
import SwiftUI

/// The volume and brightness toggle, plus what's missing while Accessibility access isn't granted.
struct SystemHUDSettings: View {
    @Bindable var settings: AppSettings
    @State private var isTrusted = AXIsProcessTrusted()

    var body: some View {
        // Turning this on shows the system prompt for Accessibility access, from HUDService.
        Toggle(isOn: $settings.replacesSystemHUD) {
            Text("Volume and brightness")
            Text("Shows volume and brightness changes next to the notch instead of the system HUD. Eyelid needs Accessibility access to handle the keys.")
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

        if settings.replacesSystemHUD {
            Picker("Level", selection: $settings.hudLevelStyle) {
                ForEach(LevelStyle.allCases, id: \.self) { style in
                    Text(style.title).tag(style)
                }
            }

            LabeledContent("Preview") {
                HUDPreview(style: settings.hudLevelStyle)
            }
        }
    }
}

/// An icon picker for every output device, so devices macOS can't tell apart get the right one.
struct OutputDeviceIconSettings: View {
    @Bindable var settings: AppSettings
    @State private var devices: [OutputDevice] = []

    var body: some View {
        ForEach(devices) { device in
            let automatic = DeviceIcon.automatic(for: device)

            Picker(selection: icon(for: device)) {
                Label("Automatic: \(automatic.title)", systemImage: automatic.availableSymbolName)
                    .tag(DeviceIcon?.none)
                Divider()
                ForEach(DeviceIcon.allCases, id: \.self) { icon in
                    Label(icon.title, systemImage: icon.availableSymbolName)
                        .tag(Optional(icon))
                }
            } label: {
                Label(device.name, systemImage: settings.icon(for: device).availableSymbolName)
            }
        }
        // Devices come and go, AirPods especially, so refresh the list while the window is open.
        .task {
            while !Task.isCancelled {
                let current = OutputDevice.all()
                if current != devices {
                    devices = current
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func icon(for device: OutputDevice) -> Binding<DeviceIcon?> {
        Binding(
            get: { settings.deviceIcons[device.id] },
            set: { settings.deviceIcons[device.id] = $0 }
        )
    }
}
