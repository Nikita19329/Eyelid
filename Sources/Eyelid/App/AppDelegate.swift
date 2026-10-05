import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    private let nowPlaying = NowPlayingService()
    private let battery = BatteryService()
    let shelf = Shelf()
    let clipboard = ClipboardHistory()
    private let hotKeys = HotKeyCenter()
    private(set) lazy var clipboardShortcut = ClipboardShortcut(center: hotKeys, settings: settings)
    private lazy var hud = HUDService(settings: settings)
    private var notchController: NotchWindowController?
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Also covers `swift run`, where there is no Info.plist with LSUIElement.
        NSApp.setActivationPolicy(.accessory)
        terminateGracefullyOnSignals()

        nowPlaying.start()
        battery.start()
        shelf.deleteUnusedPromisedFiles()
        notchController = NotchWindowController(
            nowPlaying: nowPlaying,
            battery: battery,
            shelf: shelf,
            clipboard: clipboard,
            clipboardShortcut: clipboardShortcut,
            hud: hud,
            settings: settings
        )
        followHUDSetting()
        followClipboardSetting()
    }

    func applicationWillTerminate(_ notification: Notification) {
        nowPlaying.stop()
    }

    /// Turns key handling on and off as the setting changes.
    private func followHUDSetting() {
        withObservationTracking {
            hud.setEnabled(settings.replacesSystemHUD)
        } onChange: { [weak self] in
            // `onChange` runs before the new value is stored, so apply it on the next turn of the main actor.
            Task { @MainActor in
                self?.followHUDSetting()
            }
        }
    }

    /// Watches the pasteboard while the clipboard history is on.
    private func followClipboardSetting() {
        withObservationTracking {
            let isOn = settings.clipboardEnabled
            clipboard.setMonitoring(isOn)
            // macOS lists an app under Paste from Other Apps only once it has asked to read the pasteboard.
            // Reading it once does that, and its prompt tells the user what turning the history on means.
            if isOn, clipboard.access == .notAskedYet {
                clipboard.captureCurrentContents()
            }
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.followClipboardSetting()
            }
        }
    }

    /// `kill`, `pkill` and Ctrl-C skip `applicationWillTerminate`, which would leave the adapter process running.
    private func terminateGracefullyOnSignals() {
        for signalNumber in [SIGTERM, SIGINT] {
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler {
                MainActor.assumeIsolated {
                    NSApp.terminate(nil)
                }
            }
            source.resume()
            signalSources.append(source)
        }
    }
}
