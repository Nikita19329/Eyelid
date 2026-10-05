import CoreGraphics
import Foundation
import Observation

/// User preferences, persisted in `UserDefaults`.
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let openDelay = "openDelay"
        static let hapticsEnabled = "hapticsEnabled"
        static let showsLiveActivity = "showsLiveActivity"
        static let displayID = "displayID"
    }

    /// Delays offered in Settings, in seconds.
    static let openDelayOptions: [TimeInterval] = [0, 0.1, 0.25, 0.5, 1]

    /// How long the pointer has to rest on the notch before it opens.
    var openDelay: TimeInterval {
        didSet { defaults.set(openDelay, forKey: Key.openDelay) }
    }

    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Key.hapticsEnabled) }
    }

    /// Whether artwork and an equalizer appear next to the closed notch while something plays.
    var showsLiveActivity: Bool {
        didSet { defaults.set(showsLiveActivity, forKey: Key.showsLiveActivity) }
    }

    /// The display that shows the notch, or nil to pick one automatically.
    var displayID: CGDirectDisplayID? {
        didSet {
            if let displayID {
                defaults.set(Int(displayID), forKey: Key.displayID)
            } else {
                defaults.removeObject(forKey: Key.displayID)
            }
        }
    }

    private let defaults: any SettingsStore

    init(defaults: any SettingsStore = UserDefaults.standard) {
        self.defaults = defaults
        openDelay = defaults.object(forKey: Key.openDelay) as? TimeInterval ?? 0
        hapticsEnabled = defaults.object(forKey: Key.hapticsEnabled) as? Bool ?? true
        showsLiveActivity = defaults.object(forKey: Key.showsLiveActivity) as? Bool ?? true
        displayID = (defaults.object(forKey: Key.displayID) as? Int).map { CGDirectDisplayID($0) }
    }
}

/// Where `AppSettings` keeps its values: `UserDefaults` in the app, memory in tests.
/// Any `UserDefaults` domain that gets written to stays on disk, even after `removePersistentDomain`.
protocol SettingsStore: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
}

extension UserDefaults: SettingsStore {}
