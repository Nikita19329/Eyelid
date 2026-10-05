import AudioToolbox
import CoreAudio

/// The volume of the default output device, through CoreAudio.
enum SystemVolume {
    struct State: Equatable {
        var level: Float
        var isMuted: Bool

        /// The state after a key press. Volume keys unmute, as they do in macOS.
        func after(_ key: MediaKeyPress.Key, fine: Bool) -> State {
            switch key {
            case .mute:
                State(level: level, isMuted: !isMuted)
            case .volumeUp, .volumeDown:
                State(level: LevelStep.next(from: level, up: key == .volumeUp, fine: fine), isMuted: false)
            case .brightnessUp, .brightnessDown:
                self
            }
        }
    }

    /// Nil when there is no output device, or its volume can't be set, as with many HDMI outputs.
    static func read() -> (device: AudioDeviceID, state: State)? {
        guard let device = defaultOutputDevice(),
              isSettable(volumeAddress, on: device),
              let level: Float32 = value(volumeAddress, on: device)
        else { return nil }

        let muted: UInt32 = value(muteAddress, on: device) ?? 0
        return (device, State(level: level, isMuted: muted != 0))
    }

    /// Returns false if the device rejected the change.
    static func apply(_ state: State, from old: State, on device: AudioDeviceID) -> Bool {
        if state.level != old.level, !setValue(Float32(state.level), volumeAddress, on: device) {
            return false
        }
        if state.isMuted != old.isMuted {
            guard isSettable(muteAddress, on: device) else { return false }
            return setValue(UInt32(state.isMuted ? 1 : 0), muteAddress, on: device)
        }
        return true
    }

    // MARK: - CoreAudio

    private static let volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    private static let muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    private static func defaultOutputDevice() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return status == noErr && device != kAudioObjectUnknown ? device : nil
    }

    private static func isSettable(_ address: AudioObjectPropertyAddress, on device: AudioDeviceID) -> Bool {
        var address = address
        var settable = DarwinBoolean(false)
        guard AudioObjectHasProperty(device, &address),
              AudioObjectIsPropertySettable(device, &address, &settable) == noErr
        else { return false }
        return settable.boolValue
    }

    private static func value<T>(_ address: AudioObjectPropertyAddress, on device: AudioDeviceID) -> T? {
        var address = address
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var size = UInt32(MemoryLayout<T>.size)
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, pointer) == noErr else { return nil }
        return pointer.pointee
    }

    private static func setValue<T>(_ value: T, _ address: AudioObjectPropertyAddress, on device: AudioDeviceID) -> Bool {
        var address = address
        let status = withUnsafePointer(to: value) { pointer in
            AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<T>.size), pointer)
        }
        return status == noErr
    }
}
