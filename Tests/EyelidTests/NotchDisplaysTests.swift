import CoreGraphics
import Testing
@testable import Eyelid

@Suite("Displays with a notch")
struct NotchDisplaysTests {
    /// The main display first, as NSScreen lists them: an external one, the MacBook's with its notch, a projector.
    private let displays: [(id: CGDirectDisplayID, hasNotch: Bool)] = [(7, false), (1, true), (9, false)]

    @Test func automaticPrefersTheDisplayWithANotch() {
        #expect(NotchDisplays.automatic.pick(from: displays) == [1])
    }

    @Test func automaticFallsBackToTheMainDisplay() {
        #expect(NotchDisplays.automatic.pick(from: [(7, false), (9, false)]) == [7])
        #expect(NotchDisplays.automatic.pick(from: []) == [])
    }

    @Test func allDisplaysGetANotch() {
        #expect(NotchDisplays.all.pick(from: displays) == [7, 1, 9])
    }

    @Test func aChosenDisplayWhileItsConnected() {
        #expect(NotchDisplays.display(9).pick(from: displays) == [9])
        // Unplugged: the automatic choice, until it's back.
        #expect(NotchDisplays.display(42).pick(from: displays) == [1])
    }
}

@MainActor
@Suite("Display setting")
struct NotchDisplaySettingTests {
    @Test func oneChoiceOverTwoSettings() {
        let store = InMemorySettingsStore()
        let settings = AppSettings(defaults: store)
        #expect(settings.notchDisplays == .automatic)

        settings.notchDisplays = .display(9)
        #expect(settings.displayID == 9)
        #expect(!settings.notchOnAllDisplays)

        settings.notchDisplays = .all
        #expect(settings.notchOnAllDisplays)
        #expect(AppSettings(defaults: store).notchDisplays == .all)

        settings.notchDisplays = .automatic
        #expect(settings.displayID == nil)
        #expect(!settings.notchOnAllDisplays)
    }
}
