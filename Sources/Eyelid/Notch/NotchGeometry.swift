import AppKit

/// Where the notch is on a given screen, in global AppKit coordinates (origin at the bottom left).
struct NotchGeometry: Equatable {
    /// Size of the hardware notch, or of a virtual one on displays without a notch.
    let notchSize: CGSize
    /// Horizontal center of the notch.
    let notchMidX: CGFloat
    /// Frame of the screen the notch belongs to.
    let screenFrame: CGRect
    /// The display the notch is on.
    let displayID: CGDirectDisplayID?

    init(notchSize: CGSize, notchMidX: CGFloat, screenFrame: CGRect, displayID: CGDirectDisplayID? = nil) {
        self.notchSize = notchSize
        self.notchMidX = notchMidX
        self.screenFrame = screenFrame
        self.displayID = displayID
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
                screenFrame: frame,
                displayID: screen.displayID
            )
        } else {
            let menuBarHeight = frame.maxY - screen.visibleFrame.maxY
            self.init(
                notchSize: CGSize(width: 200, height: max(menuBarHeight, 24)),
                notchMidX: frame.midX,
                screenFrame: frame,
                displayID: screen.displayID
            )
        }
    }

}

/// Which displays show a notch.
enum NotchDisplays: Hashable {
    /// The built-in display if it has a notch, otherwise the main display.
    case automatic
    case all
    /// One display, or the automatic choice while it isn't connected.
    case display(CGDirectDisplayID)

    /// Picks from the displays connected now, the main display first.
    func pick(from displays: [(id: CGDirectDisplayID, hasNotch: Bool)]) -> [CGDirectDisplayID] {
        switch self {
        case .all:
            return displays.map(\.id)
        case .display(let id) where displays.contains(where: { $0.id == id }):
            return [id]
        case .automatic, .display:
            let display = displays.first(where: \.hasNotch) ?? displays.first
            return display.map { [$0.id] } ?? []
        }
    }

    /// The screens that show a notch now.
    @MainActor
    var screens: [NSScreen] {
        let screens = NSScreen.screens
        let picked = pick(from: screens.compactMap { screen in
            screen.displayID.map { (id: $0, hasNotch: screen.safeAreaInsets.top > 0) }
        })
        return picked.compactMap { id in screens.first { $0.displayID == id } }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
