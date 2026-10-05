import AppKit
import Carbon.HIToolbox
import Testing
@testable import Eyelid

@Suite("Keys in the clipboard history")
struct ClipboardKeyTests {
    private func key(_ keyCode: Int, _ characters: String? = nil, _ flags: NSEvent.ModifierFlags = []) -> ClipboardKey {
        ClipboardKey(keyCode: keyCode, characters: characters, modifierFlags: flags)
    }

    @Test func navigation() {
        #expect(key(kVK_UpArrow, "\u{F700}") == .up)
        #expect(key(kVK_DownArrow, "\u{F701}") == .down)
        #expect(key(kVK_Return, "\r") == .choose)
        #expect(key(kVK_ANSI_KeypadEnter, "\u{3}") == .choose)
        #expect(key(kVK_Escape, "\u{1B}") == .escape)
    }

    @Test func deleteEditsTheSearchAndCommandDeleteRemoves() {
        #expect(key(kVK_Delete, "\u{7F}") == .deleteBackward)
        #expect(key(kVK_Delete, "\u{7F}", .command) == .remove)
        #expect(key(kVK_ForwardDelete, "\u{F728}", .command) == .remove)
    }

    @Test func shortcuts() {
        #expect(key(kVK_ANSI_P, "p", .command) == .togglePin)
        #expect(key(kVK_ANSI_Y, "y", .command) == .togglePreview)
        #expect(key(kVK_Space, " ") == .space)
    }

    @Test func textGoesToTheSearch() {
        #expect(key(kVK_ANSI_A, "a") == .type("a"))
        #expect(key(kVK_ANSI_A, "A", .shift) == .type("A"))
        #expect(key(kVK_ANSI_C, "с") == .type("с"))
        #expect(key(kVK_ANSI_8, "•", .option) == .type("•"))
    }

    @Test func otherShortcutsAndFunctionKeysAreNotText() {
        #expect(key(kVK_ANSI_C, "c", .command) == .other)
        #expect(key(kVK_ANSI_A, "a", .control) == .other)
        #expect(key(kVK_F5, "\u{F708}") == .other)
        #expect(key(kVK_ANSI_P, "p", [.command, .shift]) == .other)
        #expect(key(kVK_Tab, "\t") == .other)
    }
}
