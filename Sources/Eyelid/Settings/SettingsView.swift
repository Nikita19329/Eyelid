import SwiftUI

/// Tabs, like System Settings panes in other Mac apps, so no tab grows taller than the screen.
struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        TabView {
            GeneralSettings(settings: settings)
                .tabItem { Label("General", systemImage: "gearshape") }
            NotchSettings(settings: settings)
                .tabItem { Label("Notch", systemImage: "rectangle.topthird.inset.filled") }
            VolumeAndBrightnessSettings(settings: settings)
                .tabItem { Label("Volume & Brightness", systemImage: "speaker.wave.2") }
            BatterySettings(settings: settings)
                .tabItem { Label("Battery", systemImage: "battery.75percent") }
            AboutSettings()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
    }

    /// The width every tab shares, so the window doesn't jump sideways when switching tabs.
    static let width: CGFloat = 500
}

private struct GeneralSettings: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                LaunchAtLoginToggle()

                Picker(selection: $settings.displayID) {
                    Text("Automatic").tag(CGDirectDisplayID?.none)
                    ForEach(NSScreen.screens, id: \.self) { screen in
                        Text(screen.localizedName).tag(screen.displayID)
                    }
                } label: {
                    Text("Display")
                    Text("Automatic uses the built-in display if it has a notch.")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: SettingsView.width)
        .fixedSize()
    }
}

private struct NotchSettings: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("Open on hover", selection: $settings.openDelay) {
                    ForEach(AppSettings.openDelayOptions, id: \.self) { delay in
                        Text(Self.label(forDelay: delay)).tag(delay)
                    }
                }

                Toggle(isOn: $settings.hapticsEnabled) {
                    Text("Haptic feedback when opening")
                    // macOS drops the feedback otherwise, which is easy to hit with an open delay.
                    Text("Plays only while your finger is on the trackpad.")
                }

                Toggle(isOn: $settings.showsLiveActivity) {
                    Text("Live activity")
                    Text("Shows the artwork and an equalizer next to the notch while something plays.")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: SettingsView.width)
        .fixedSize()
    }

    private static func label(forDelay delay: TimeInterval) -> String {
        delay == 0 ? "Instantly" : "After \(delay.formatted()) s"
    }
}

private struct VolumeAndBrightnessSettings: View {
    @Bindable var settings: AppSettings
    @State private var devices = OutputDevice.all()

    /// Rows that fit on a 14-inch screen along with the rest of the tab.
    private static let maxDevicesWithoutScrolling = 5

    private var scrolls: Bool {
        devices.count > Self.maxDevicesWithoutScrolling
    }

    var body: some View {
        Form {
            Section {
                SystemHUDSettings(settings: settings)
            }

            if settings.replacesSystemHUD {
                Section {
                    OutputDeviceIconSettings(settings: settings, devices: devices)
                } header: {
                    Text("Output devices")
                } footer: {
                    Text("The icon the volume HUD shows for each device. macOS knows AirPods and Beats, but other Bluetooth devices all look like headphones to it.")
                }
            }
        }
        .formStyle(.grouped)
        // Fits the content, unless a long device list would push the window off the screen: then it scrolls.
        .frame(width: SettingsView.width, height: scrolls ? 560 : nil)
        .fixedSize(horizontal: true, vertical: !scrolls)
        // On the Form, which always exists: on the list itself, this would run once per device, or never.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                let current = OutputDevice.all()
                if current != devices {
                    devices = current
                }
            }
        }
    }
}

private struct BatterySettings: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.batteryActivityEnabled) {
                    Text("Battery activity")
                    Text("Shows the charge next to the notch when you plug in or unplug the charger, and when the battery drops to 20% and 10%.")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: SettingsView.width)
        .fixedSize()
    }
}

private struct AboutSettings: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: Self.version)
                LabeledContent("License", value: "GNU GPL v3")
                Link("Source code on GitHub", destination: URL(string: "https://github.com/Nikita19329/Eyelid")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: SettingsView.width)
        .fixedSize()
    }

    /// "1.2.3 (45)": builds made after the same tag differ only in the build number.
    private static var version: String {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        else { return "development build" }
        return "\(version) (\(build))"
    }
}
