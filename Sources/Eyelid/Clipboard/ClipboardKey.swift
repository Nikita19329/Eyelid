import AppKit
import Carbon.HIToolbox

/// What a key press does in the open clipboard history.
enum ClipboardKey: Equatable {
    case up
    case down
    /// Return: copies the selected entry.
    case choose
    /// ⌘⌫: removes the selected entry.
    case remove
    /// ⌘P
    case togglePin
    /// ⌘Y, as Quick Look in Finder.
    case togglePreview
    /// Space previews the selection, or types a space once there's a search.
    case space
    case deleteBackward
    case escape
    /// Text for the search.
    case type(String)
    case other

    init(keyCode: Int, characters: String?, modifierFlags: NSEvent.ModifierFlags) {
        let modifiers = modifierFlags.intersection([.command, .control, .option, .shift])
        let isCommand = modifiers.contains(.command)

        switch keyCode {
        case kVK_UpArrow: self = .up
        case kVK_DownArrow: self = .down
        case kVK_Return, kVK_ANSI_KeypadEnter: self = .choose
        case kVK_Escape: self = .escape
        case kVK_Delete, kVK_ForwardDelete: self = isCommand ? .remove : .deleteBackward
        case kVK_ANSI_P where modifiers == .command: self = .togglePin
        case kVK_ANSI_Y where modifiers == .command: self = .togglePreview
        case kVK_Space where modifiers.isEmpty: self = .space
        default:
            // Shortcuts with ⌘ or ⌃ aren't text. Characters typed with ⇧ or ⌥ are, as in any text field.
            guard !isCommand, !modifiers.contains(.control),
                  let characters, !characters.isEmpty,
                  characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }),
                  // Arrow and function keys come as characters from Unicode's private use area.
                  !characters.unicodeScalars.contains(where: { (0xF700...0xF8FF).contains($0.value) })
            else {
                self = .other
                return
            }
            self = .type(characters)
        }
    }

    init(event: NSEvent) {
        self.init(keyCode: Int(event.keyCode), characters: event.characters, modifierFlags: event.modifierFlags)
    }
}
