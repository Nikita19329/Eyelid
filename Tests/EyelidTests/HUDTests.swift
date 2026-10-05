import AppKit
import Testing
@testable import Eyelid

@Suite("Volume and brightness keys")
struct MediaKeyPressTests {
    /// `data1` the way macOS packs it: key code, key state (0xA down, 0xB up) and the repeat flag.
    private func data1(code: Int, down: Bool = true, isRepeat: Bool = false) -> Int {
        code << 16 | (down ? 0xA : 0xB) << 8 | (isRepeat ? 1 : 0)
    }

    @Test(arguments: zip(
        [0, 1, 7, 2, 3],
        [MediaKeyPress.Key.volumeUp, .volumeDown, .mute, .brightnessUp, .brightnessDown]
    ))
    func decodesKeys(code: Int, key: MediaKeyPress.Key) throws {
        let press = try #require(MediaKeyPress(data1: data1(code: code), modifierFlags: []))

        #expect(press.key == key)
        #expect(press.isKeyDown)
        #expect(!press.isRepeat)
    }

    @Test func decodesKeyUpAndRepeat() throws {
        let up = try #require(MediaKeyPress(data1: data1(code: 0, down: false), modifierFlags: []))
        let held = try #require(MediaKeyPress(data1: data1(code: 0, isRepeat: true), modifierFlags: []))

        #expect(!up.isKeyDown)
        #expect(held.isRepeat)
    }

    @Test func leavesOtherMediaKeysAlone() {
        // 16 is play/pause, which belongs to now playing apps.
        #expect(MediaKeyPress(data1: data1(code: 16), modifierFlags: []) == nil)
        #expect(MediaKeyPress(data1: 0 << 16 | 0x0C00, modifierFlags: []) == nil)
    }

    @Test func optionShiftMakesFineSteps() throws {
        let press = try #require(MediaKeyPress(data1: data1(code: 0), modifierFlags: [.option, .shift]))

        #expect(press.isFineStep)
        #expect(!press.opensSystemSettings)
    }

    @Test func optionAloneIsLeftToMacOS() throws {
        let press = try #require(MediaKeyPress(data1: data1(code: 0), modifierFlags: [.option]))

        #expect(press.opensSystemSettings)
        #expect(!press.isFineStep)
    }
}

@Suite("Volume and brightness levels")
struct LevelTests {
    @Test func stepsBySixteenths() {
        #expect(LevelStep.next(from: 0.5, up: true, fine: false) == 0.5625)
        #expect(LevelStep.next(from: 0.5, up: false, fine: false) == 0.4375)
    }

    @Test func finerStepsWithOptionShift() {
        #expect(LevelStep.next(from: 0.5, up: true, fine: true) == 0.515625)
    }

    @Test func snapsToTheGridFirst() {
        // 0.26 is 4.16 sixteenths, so it snaps to 4 before stepping.
        #expect(LevelStep.next(from: 0.26, up: true, fine: false) == 0.3125)
        #expect(LevelStep.next(from: 0.26, up: false, fine: false) == 0.1875)
    }

    @Test func staysWithinZeroAndOne() {
        #expect(LevelStep.next(from: 1, up: true, fine: false) == 1)
        #expect(LevelStep.next(from: 0, up: false, fine: false) == 0)
        #expect(LevelStep.next(from: 0.03, up: false, fine: false) == 0)
    }

    @Test func muteKeyTogglesMute() {
        let state = SystemVolume.State(level: 0.5, isMuted: false)

        #expect(state.after(.mute, fine: false) == SystemVolume.State(level: 0.5, isMuted: true))
        #expect(state.after(.mute, fine: false).after(.mute, fine: false) == state)
    }

    @Test func volumeKeysUnmute() {
        let muted = SystemVolume.State(level: 0.5, isMuted: true)

        #expect(muted.after(.volumeUp, fine: false) == SystemVolume.State(level: 0.5625, isMuted: false))
        #expect(muted.after(.volumeDown, fine: false) == SystemVolume.State(level: 0.4375, isMuted: false))
    }

    @Test(arguments: zip(
        [0, 0.2, 0.5, 0.9] as [Float],
        ["speaker.slash.fill", "speaker.wave.1.fill", "speaker.wave.2.fill", "speaker.wave.3.fill"]
    ))
    func volumeIconFollowsTheLevel(level: Float, symbol: String) {
        #expect(HUDEvent(kind: .volume, level: level).symbolName == symbol)
    }

    @Test func mutedVolumeShowsTheMutedIcon() {
        #expect(HUDEvent(kind: .volume, level: 0.8, isMuted: true).symbolName == "speaker.slash.fill")
    }

    @Test func brightnessIconFollowsTheLevel() {
        #expect(HUDEvent(kind: .brightness, level: 0.2).symbolName == "sun.min.fill")
        #expect(HUDEvent(kind: .brightness, level: 0.8).symbolName == "sun.max.fill")
    }
}
