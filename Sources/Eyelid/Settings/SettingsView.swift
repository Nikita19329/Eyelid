import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("General") {
                LaunchAtLoginToggle()
            }

            Section("Notch") {
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

            Section("Volume and brightness") {
                SystemHUDSettings(settings: settings)
            }

            if settings.replacesSystemHUD {
                Section {
                    OutputDeviceIconSettings(settings: settings)
                } header: {
                    Text("Output devices")
                } footer: {
                    Text("The icon the volume HUD shows for each device. macOS knows AirPods and Beats, but other Bluetooth devices all look like headphones to it.")
                }
            }

            Section("Battery") {
                Toggle(isOn: $settings.batteryActivityEnabled) {
                    Text("Battery activity")
                    Text("Shows the charge next to the notch when you plug in or unplug the charger, and when the battery drops to 20% and 10%.")
                }
            }

            Section {
                LabeledContent("Version", value: Self.version)
                Link("Source code on GitHub", destination: URL(string: "https://github.com/Nikita19329/Eyelid")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize()
    }

    private static func label(forDelay delay: TimeInterval) -> String {
        delay == 0 ? "Instantly" : "After \(delay.formatted()) s"
    }

    /// "1.2.3 (45)": builds made after the same tag differ only in the build number.
    private static var version: String {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        else { return "development build" }
        return "\(version) (\(build))"
    }
}
