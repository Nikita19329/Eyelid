import ServiceManagement
import SwiftUI

/// Registers Eyelid as a login item with `SMAppService`. The system keeps the list of login items,
/// so the toggle only mirrors its status and there is nothing to store on our side.
struct LaunchAtLoginToggle: View {
    @State private var status = SMAppService.mainApp.status
    @State private var errorMessage: String?

    var body: some View {
        Toggle("Launch at login", isOn: Binding(
            get: { status == .enabled || status == .requiresApproval },
            set: { setEnabled($0) }
        ))
        // The user can also change this in System Settings while our window is in the background.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            status = SMAppService.mainApp.status
        }

        if status == .requiresApproval {
            LabeledContent("Allow Eyelid in Login Items to finish.") {
                Button("Open Login Items") {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
            .foregroundStyle(.secondary)
        }

        if let errorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
        }
    }

    private func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = "Could not \(enabled ? "enable" : "disable") launch at login: \(error.localizedDescription)"
        }
        status = SMAppService.mainApp.status
    }
}
