import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    private let nowPlaying = NowPlayingService()
    private let battery = BatteryService()
    private let hud = HUDService()
    private var notchController: NotchWindowController?
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Also covers `swift run`, where there is no Info.plist with LSUIElement.
        NSApp.setActivationPolicy(.accessory)
        terminateGracefullyOnSignals()

        nowPlaying.start()
        battery.start()
        notchController = NotchWindowController(nowPlaying: nowPlaying, battery: battery, hud: hud, settings: settings)
        followHUDSetting()
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
