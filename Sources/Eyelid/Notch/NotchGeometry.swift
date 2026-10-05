import AppKit

/// Where the notch is on a given screen, in global AppKit coordinates (origin at the bottom left).
struct NotchGeometry: Equatable {
    /// Size of the hardware notch, or of a virtual one on displays without a notch.
    let notchSize: CGSize
    /// Horizontal center of the notch.
    let notchMidX: CGFloat
    /// Frame of the screen the notch belongs to.
    let screenFrame: CGRect

    init(screen: NSScreen) {
        let frame = screen.frame
        screenFrame = frame

        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            // The notch is whatever the two auxiliary areas next to it leave uncovered.
            let width = frame.width - left.width - right.width
            notchSize = CGSize(width: width, height: screen.safeAreaInsets.top)
            notchMidX = frame.minX + left.width + width / 2
        } else {
            let menuBarHeight = frame.maxY - screen.visibleFrame.maxY
            notchSize = CGSize(width: 200, height: max(menuBarHeight, 24))
            notchMidX = frame.midX
        }
    }

    /// The built-in display if it has a notch, otherwise the main display.
    static func preferredScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }
}
