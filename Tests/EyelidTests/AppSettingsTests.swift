import Foundation
import Testing
@testable import Eyelid

@MainActor
@Suite("Settings")
struct AppSettingsTests {
    @Test func defaultsWhenNothingIsStored() {
        let settings = AppSettings(defaults: InMemorySettingsStore())

        #expect(settings.openDelay == 0)
        #expect(settings.hapticsEnabled)
        #expect(settings.showsLiveActivity)
        #expect(settings.batteryActivityEnabled)
        #expect(!settings.replacesSystemHUD)
        #expect(settings.displayID == nil)
    }

    @Test func changesSurviveARelaunch() {
        let store = InMemorySettingsStore()
        let settings = AppSettings(defaults: store)
        settings.openDelay = 0.25
        settings.hapticsEnabled = false
        settings.showsLiveActivity = false
        settings.batteryActivityEnabled = false
        settings.replacesSystemHUD = true
        settings.displayID = 42

        let relaunched = AppSettings(defaults: store)

        #expect(relaunched.openDelay == 0.25)
        #expect(!relaunched.hapticsEnabled)
        #expect(!relaunched.showsLiveActivity)
        #expect(!relaunched.batteryActivityEnabled)
        #expect(relaunched.replacesSystemHUD)
        #expect(relaunched.displayID == 42)
    }

    @Test func automaticDisplayRemovesTheStoredOne() {
        let store = InMemorySettingsStore()
        let settings = AppSettings(defaults: store)
        settings.displayID = 42

        settings.displayID = nil

        #expect(store.object(forKey: "displayID") == nil)
        #expect(AppSettings(defaults: store).displayID == nil)
    }

    @Test func offeredDelaysStartWithInstantly() {
        #expect(AppSettings.openDelayOptions.first == 0)
        #expect(AppSettings.openDelayOptions == AppSettings.openDelayOptions.sorted())
    }
}

/// Keeps settings in memory, so tests neither read nor write the real preferences.
final class InMemorySettingsStore: SettingsStore {
    private var values: [String: Any] = [:]

    func object(forKey key: String) -> Any? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
    func removeObject(forKey key: String) { values[key] = nil }
}
