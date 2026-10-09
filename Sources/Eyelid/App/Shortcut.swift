import Observation

/// Keeps a global shortcut registered while it's turned on, and follows changes to it in Settings: the clipboard
/// history's, and the one that hides the live activity.
@MainActor
@Observable
final class Shortcut {
    @ObservationIgnored var onPress: (@MainActor () -> Void)?

    /// Whether another app already has the shortcut, so it does nothing here.
    private(set) var isTaken = false
    /// Set while Settings records a new shortcut, so pressing the current one records it instead of acting on it.
    var isSuspended = false

    @ObservationIgnored private let center: HotKeyCenter
    @ObservationIgnored private let isEnabled: @MainActor () -> Bool
    @ObservationIgnored private let hotKey: @MainActor () -> HotKey
    @ObservationIgnored private var registration: HotKeyCenter.Registration?

    /// `isEnabled` and `hotKey` read settings, which are followed as they change.
    init(center: HotKeyCenter, isEnabled: @escaping @MainActor () -> Bool, hotKey: @escaping @MainActor () -> HotKey) {
        self.center = center
        self.isEnabled = isEnabled
        self.hotKey = hotKey
        follow()
    }

    private func follow() {
        withObservationTracking {
            update(isOn: isEnabled() && !isSuspended, hotKey: hotKey())
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
