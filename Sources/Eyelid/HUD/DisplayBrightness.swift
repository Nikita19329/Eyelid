import CoreGraphics
import Foundation

/// The built-in display's brightness.
///
/// macOS has no public API for it, so this calls the private DisplayServices framework, as MonitorControl
/// and similar utilities do. Everything degrades to nil or false if a macOS update removes the functions.
enum DisplayBrightness {
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias CanChangeBrightness = @convention(c) (CGDirectDisplayID) -> Bool

    private struct Functions: @unchecked Sendable {
        let get: GetBrightness
        let set: SetBrightness
        let canChange: CanChangeBrightness
    }

    private static let functions: Functions? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW),
              let get = dlsym(handle, "DisplayServicesGetBrightness"),
              let set = dlsym(handle, "DisplayServicesSetBrightness"),
              let canChange = dlsym(handle, "DisplayServicesCanChangeBrightness")
        else { return nil }

        return Functions(
            get: unsafeBitCast(get, to: GetBrightness.self),
            set: unsafeBitCast(set, to: SetBrightness.self),
            canChange: unsafeBitCast(canChange, to: CanChangeBrightness.self)
        )
    }()

    /// The built-in display, if it's on and its brightness can be changed.
    static var builtInDisplay: CGDirectDisplayID? {
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(UInt32(displays.count), &displays, &count) == .success,
              let functions
        else { return nil }

        return displays.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 && functions.canChange($0) }
    }

    static func level(of display: CGDirectDisplayID) -> Float? {
        guard let functions else { return nil }
        var level: Float = 0
        return functions.get(display, &level) == 0 ? level : nil
    }

    static func setLevel(_ level: Float, of display: CGDirectDisplayID) -> Bool {
        functions?.set(display, level) == 0
    }
}
