import Observation

/// Keeps the clipboard shortcut registered while the history is on, and follows changes to it in Settings.
@MainActor
@Observable
final class ClipboardShortcut {
    @ObservationIgnored var onPress: (@MainActor () -> Void)?

    /// Whether another app already has the shortcut, so it can't open the history.
    private(set) var isTaken = false
    /// Set while Settings records a new shortcut, so pressing the current one records it instead of opening
    /// the history.
    var isSuspended = false

    @ObservationIgnored private let center: HotKeyCenter
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var registration: HotKeyCenter.Registration?

    init(center: HotKeyCenter, settings: AppSettings) {
        self.center = center
        self.settings = settings
        follow()
    }

    private func follow() {
        withObservationTracking {
            update(isOn: settings.clipboardEnabled && !isSuspended, hotKey: settings.clipboardHotKey)
        } onChange: { [weak self] in
            // `onChange` runs before the new value is stored, so read it on the next turn of the main actor.
            Task { @MainActor in
                self?.follow()
            }
        }
    }

    private func update(isOn: Bool, hotKey: HotKey) {
        if let registration {
            center.unregister(registration)
            self.registration = nil
        }
        guard isOn else {
            isTaken = false
            return
        }
        registration = center.register(hotKey) { [weak self] in
            self?.onPress?()
        }
        isTaken = registration == nil
    }
}
