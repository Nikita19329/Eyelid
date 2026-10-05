import AppKit
import Observation

@MainActor
@Observable
final class NotchViewModel {
    enum State {
        case closed
        case open
    }

    /// What the open notch shows below the strip beside the hardware notch.
    enum Tab {
        case nowPlaying
        case shelf
    }

    enum Layout {
        static let openWidth: CGFloat = 440
        /// Height of the open notch below the hardware notch strip.
        static let openContentHeight: CGFloat = 108
        /// Extra room on each side of the closed notch for the live activity.
        static let activitySideWidth: CGFloat = 42
        /// Room on each side of the closed notch for the volume and brightness HUD.
        static let hudSideWidth: CGFloat = 70
        /// How long the HUD stays after the last key press, in seconds.
        static let hudDuration: TimeInterval = 1.5
        /// How long a battery event stays next to the closed notch, in seconds.
        static let batteryEventDuration: TimeInterval = 3
        /// Transparent margin around the open notch so its shadow is not clipped.
        static let shadowPadding: CGFloat = 40
        /// How far around the closed notch dragged files open it, which makes the notch easier to hit.
        static let fileDragMargin: CGFloat = 24

        static let closedTopRadius: CGFloat = 6
        static let closedBottomRadius: CGFloat = 10
        static let openTopRadius: CGFloat = 14
        static let openBottomRadius: CGFloat = 26
    }

    var state: State = .closed
    var tab: Tab = .nowPlaying
    var geometry: NotchGeometry
    /// The volume or brightness after a key press. Shown in place of everything else.
    var hud: HUDEvent?
    /// Shown next to the closed notch for a few seconds, in place of now playing.
    var batteryEvent: BatteryEvent?
    /// Whether files are being dragged anywhere on the screen, which may end on the notch.
    var isDraggingFiles = false
    /// Whether files are being dragged over the open notch, which would add them to the shelf.
    var isDropTargeted = false
    let nowPlaying: NowPlayingService
    let battery: BatteryService
    let shelf: Shelf
    let settings: AppSettings
    @ObservationIgnored let shelfDragSource = ShelfDragSource()

    init(
        geometry: NotchGeometry,
        nowPlaying: NowPlayingService,
        battery: BatteryService,
        shelf: Shelf,
        settings: AppSettings
    ) {
        self.geometry = geometry
        self.nowPlaying = nowPlaying
        self.battery = battery
        self.shelf = shelf
        self.settings = settings
        shelfDragSource.onDrop = { [weak self] items in
            self?.didDragOut(items)
        }
    }

    /// Whether the open notch shows the shelf rather than now playing.
    var showsShelf: Bool {
        settings.shelfEnabled && tab == .shelf
    }

    private func didDragOut(_ items: [ShelfItem.ID]) {
        guard settings.shelfRemovesDraggedFiles else { return }
        for item in items {
            shelf.remove(item)
        }
    }

    /// Whether the closed notch grows sideways to show the HUD, a battery event, or artwork and an equalizer.
    var showsActivity: Bool {
        hud != nil || batteryEvent != nil || showsNowPlayingActivity
    }

    var showsNowPlayingActivity: Bool {
        settings.showsLiveActivity && nowPlaying.track?.isPlaying == true
    }

    /// Size of the notch body, excluding the ears.
    var bodySize: CGSize {
        let notch = geometry.notchSize
        switch state {
        case .open:
            return CGSize(width: Layout.openWidth, height: notch.height + Layout.openContentHeight)
        case .closed:
            let sideWidth = hud != nil ? Layout.hudSideWidth : (showsActivity ? Layout.activitySideWidth : 0)
            let extra = 2 * sideWidth
            return CGSize(width: notch.width + extra, height: notch.height)
        }
    }

    var topRadius: CGFloat {
        state == .open ? Layout.openTopRadius : Layout.closedTopRadius
    }

    var bottomRadius: CGFloat {
        state == .open ? Layout.openBottomRadius : Layout.closedBottomRadius
    }

    /// The panel is sized once for the open state and never resized, which keeps animations smooth.
    var windowSize: CGSize {
        CGSize(
            width: Layout.openWidth + 2 * Layout.openTopRadius + 2 * Layout.shadowPadding,
            height: geometry.notchSize.height + Layout.openContentHeight + Layout.shadowPadding
        )
    }

    /// The notch body in global coordinates.
    var bodyRect: CGRect {
        let size = bodySize
        return CGRect(
            x: geometry.notchMidX - size.width / 2,
            y: geometry.screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    /// Area in global coordinates where the cursor opens the notch, or keeps it open.
    /// The open area is more forgiving, so the notch does not flicker at its edge.
    var hoverRect: CGRect {
        let margin: CGFloat
        switch state {
        case .open:
            margin = 12
        case .closed:
            margin = isDraggingFiles && settings.shelfEnabled ? Layout.fileDragMargin : 4
        }
        return bodyRect.insetBy(dx: -margin, dy: -margin)
    }
}
