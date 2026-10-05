import AppKit

/// A volume, mute or brightness key press, decoded from a system-defined event.
struct MediaKeyPress: Equatable {
    enum Key: Equatable {
        case volumeUp
        case volumeDown
        case mute
        case brightnessUp
        case brightnessDown
    }

    /// The subtype of system-defined events that carry media keys (`NX_SUBTYPE_AUX_CONTROL_BUTTONS`).
    static let auxControlButtonsSubtype: Int16 = 8

    let key: Key
    let isKeyDown: Bool
    let isRepeat: Bool
    /// Option-Shift changes the level in quarter steps, as it does for the system.
    let isFineStep: Bool
    /// Option alone opens Sound or Displays settings in macOS, so those presses are left to the system.
    let opensSystemSettings: Bool

    /// Decodes `data1` of an aux control button event: the `NX_KEYTYPE_*` code in the high 16 bits,
    /// then the key state (0xA down, 0xB up) and a repeat flag in the low ones.
    init?(data1: Int, modifierFlags: NSEvent.ModifierFlags) {
        switch (data1 & 0xFFFF_0000) >> 16 {
        case 0: key = .volumeUp
        case 1: key = .volumeDown
        case 2: key = .brightnessUp
        case 3: key = .brightnessDown
        case 7: key = .mute
        default: return nil
        }

        let flags = data1 & 0xFFFF
        let state = (flags & 0xFF00) >> 8
        guard state == 0xA || state == 0xB else { return nil }

        isKeyDown = state == 0xA
        isRepeat = flags & 0x1 == 1
        isFineStep = modifierFlags.contains([.option, .shift])
        opensSystemSettings = modifierFlags.contains(.option) && !modifierFlags.contains(.shift)
    }
}

enum LevelStep {
    /// The next level on the system's grid: 16 steps, or 64 with Option-Shift.
    /// The current level snaps to the grid first, so values set elsewhere line up again.
    static func next(from level: Float, up: Bool, fine: Bool) -> Float {
        let steps: Float = fine ? 64 : 16
        let current = (level * steps).rounded()
        let target = up ? current + 1 : current - 1
        return min(max(target / steps, 0), 1)
    }
}
