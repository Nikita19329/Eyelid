import AppKit

/// Where the notch is on a given screen, in global AppKit coordinates (origin at the bottom left).
struct NotchGeometry: Equatable {
    /// Size of the hardware notch, or of a virtual one on displays without a notch.
    let notchSize: CGSize
    /// Horizontal center of the notch.
    let notchMidX: CGFloat
    /// Frame of the screen the notch belongs to.
    let screenFrame: CGRect

    init(notchSize: CGSize, notchMidX: CGFloat, screenFrame: CGRect) {
        self.notchSize = notchSize
        self.notchMidX = notchMidX
        self.screenFrame = screenFrame
    }

    init(screen: NSScreen) {
        let frame = screen.frame

        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            // The notch is whatever the two auxiliary areas next to it leave uncovered.
            let width = frame.width - left.width - right.width
            self.init(
                notchSize: CGSize(width: width, height: screen.safeAreaInsets.top),
                notchMidX: frame.minX + left.width + width / 2,
                screenFrame: frame
            )
        } else {
            let menuBarHeight = frame.maxY - screen.visibleFrame.maxY
            self.init(
                notchSize: CGSize(width: 200, height: max(menuBarHeight, 24)),
                notchMidX: frame.midX,
                screenFrame: frame
            )
        }
    }

    /// The chosen display if it is connected. Otherwise the built-in display if it has a notch,
    /// otherwise the main display.
    static func preferredScreen(displayID: CGDirectDisplayID?) -> NSScreen? {
        if let displayID, let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) {
            return screen
        }
        return NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
