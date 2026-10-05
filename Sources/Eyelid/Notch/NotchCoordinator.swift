import AppKit
import Observation

/// Keeps a notch on each display that should show one, as displays come and go and the setting changes, and sends
/// each event to the notch the user is looking at.
@MainActor
final class NotchCoordinator {
    private let nowPlaying: NowPlayingService
    private let battery: BatteryService
    private let shelf: Shelf
    private let clipboard: ClipboardHistory
    private let settings: AppSettings
    private var controllers: [NotchWindowController] = []

    init(
        nowPlaying: NowPlayingService,
        battery: BatteryService,
        output: OutputService,
        shelf: Shelf,
        clipboard: ClipboardHistory,
        clipboardShortcut: ClipboardShortcut,
        hud: HUDService,
        settings: AppSettings
    ) {
        self.nowPlaying = nowPlaying
        self.battery = battery
        self.shelf = shelf
        self.clipboard = clipboard
        self.settings = settings

        updateNotches()
        followDisplaySetting()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateNotches()
            }
        }

        battery.onEvent = { [weak self] event in
            self?.activeNotch?.show(event)
        }
        output.onEvent = { [weak self] event in
            self?.activeNotch?.show(event)
        }
        hud.onEvent = { [weak self] event in
            self?.activeNotch?.show(event)
        }
        clipboardShortcut.onPress = { [weak self] in
            self?.toggleClipboard()
        }
    }

    /// The notch on the display with the pointer, which is where the user is looking.
    private var activeNotch: NotchWindowController? {
        let pointer = NSEvent.mouseLocation
        return controllers.first { $0.screenFrame.contains(pointer) } ?? controllers.first
    }

    /// Opens the clipboard history where the user is looking, or closes it wherever it's open.
    private func toggleClipboard() {
        if let open = controllers.first(where: \.isHoldingClipboardOpen) {
            open.toggleClipboard()
        } else {
            activeNotch?.toggleClipboard()
        }
    }

    // MARK: - Displays

    private func followDisplaySetting() {
        withObservationTracking {
            _ = settings.notchDisplays
        } onChange: { [weak self] in
            // `onChange` runs before the new value is stored, so read it on the next turn of the main actor.
            Task { @MainActor in
                self?.updateNotches()
                self?.followDisplaySetting()
            }
        }
    }

    /// Keeps the notches of displays that still show one, adds the new ones, and takes down the rest.
    private func updateNotches() {
        let screens = settings.notchDisplays.screens
        var kept: [NotchWindowController] = []

        for screen in screens {
            if let controller = controllers.first(where: { $0.displayID == screen.displayID }) {
                controller.move(to: screen)
                kept.append(controller)
            } else {
                kept.append(NotchWindowController(
                    screen: screen,
                    nowPlaying: nowPlaying,
                    battery: battery,
                    shelf: shelf,
                    clipboard: clipboard,
                    settings: settings
                ))
            }
        }

        for controller in controllers where !kept.contains(where: { $0 === controller }) {
            controller.invalidate()
        }
        controllers = kept
    }
}
