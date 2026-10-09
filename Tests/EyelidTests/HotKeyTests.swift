import AppKit
import Carbon.HIToolbox
import Testing
@testable import Eyelid

@MainActor
@Suite("Keyboard shortcuts")
struct HotKeyTests {
    @Test func needsCommandOptionOrControl() {
        #expect(HotKey(keyCode: UInt16(kVK_ANSI_V), modifierFlags: [.shift]) == nil)
        #expect(HotKey(keyCode: UInt16(kVK_ANSI_V), modifierFlags: []) == nil)
        #expect(HotKey(keyCode: UInt16(kVK_ANSI_V), modifierFlags: [.command, .shift]) == .clipboardDefault)
        #expect(HotKey(keyCode: UInt16(kVK_ANSI_C), modifierFlags: [.option]) != nil)
    }

    @Test func readsLikeAMenuShortcut() {
        #expect(HotKey.clipboardDefault.displayString == "⇧⌘V")
        #expect(HotKey.liveActivityDefault.displayString == "⌥Z")
        let all = HotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey | shiftKey | cmdKey))
        #expect(all.displayString == "⌃⌥⇧⌘Space")
        #expect(HotKey(keyCode: UInt32(kVK_F5), modifiers: UInt32(optionKey)).displayString == "⌥F5")
    }
}
