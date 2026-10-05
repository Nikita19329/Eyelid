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

                Toggle("Haptic feedback when opening", isOn: $settings.hapticsEnabled)

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

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development build"
    }
}
