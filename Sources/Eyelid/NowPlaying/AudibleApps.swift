import CoreAudio

/// Which apps are sending sound to an output right now, as Core Audio sees it (macOS 14.2 and later). No permission
/// is needed: it says whether an app plays, not what.
///
/// Something reported as playing can be silent: YouTube in a browser plays muted previews as the pointer passes over
/// them, and reports each one as now playing. Those send no sound at all.
enum AudibleApps {
    /// Whether an app with one of these bundle identifiers, or a helper of one, such as Chrome's, is sending sound.
    /// Nil when that can't be told: before macOS 14.2, or when Core Audio knows no process of the app.
    static func isAudible(_ bundleIdentifiers: [String]) -> Bool? {
        guard #available(macOS 14.2, *), !bundleIdentifiers.isEmpty else { return nil }

        var known = false
        for process in AudioProperty.array(
            AudioProperty.address(kAudioHardwarePropertyProcessObjectList),
            of: AudioObjectID(kAudioObjectSystemObject)
        ) as [AudioObjectID] {
            guard let bundle = AudioProperty.string(AudioProperty.address(kAudioProcessPropertyBundleID), of: process),
                  matches(bundle, bundleIdentifiers)
            else { continue }
            known = true
            let running: UInt32 = AudioProperty.value(AudioProperty.address(kAudioProcessPropertyIsRunningOutput), of: process) ?? 0
            if running != 0 {
                return true
            }
        }
        return known ? false : nil
    }

    /// The app itself, or one of its helpers, whose bundle identifiers extend the app's.
    static func matches(_ bundle: String, _ bundleIdentifiers: [String]) -> Bool {
        bundleIdentifiers.contains { bundle == $0 || bundle.hasPrefix($0 + ".") }
    }
}
