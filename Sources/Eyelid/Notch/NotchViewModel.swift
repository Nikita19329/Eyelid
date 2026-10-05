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
        case clipboard
    }

    enum Layout {
        static let openWidth: CGFloat = 440
        /// Height of the open notch below the hardware notch strip.
        static let openContentHeight: CGFloat = 108
        /// The clipboard history needs room for a list, so the notch grows taller for it.
        static let clipboardContentHeight: CGFloat = 236
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
    /// Whether the notch stays open wherever the pointer goes: after the clipboard shortcut, until an entry is
    /// picked, Escape is pressed or the user clicks elsewhere.
    var isPinned = false
    /// The clipboard entry that Return copies, by its place in the list.
    var clipboardSelection = 0
    let nowPlaying: NowPlayingService
    let battery: BatteryService
    let shelf: Shelf
    let clipboard: ClipboardHistory
    let settings: AppSettings
    @ObservationIgnored let shelfDragSource = ShelfDragSource()
    /// Set by the window controller, which owns opening and closing.
    @ObservationIgnored var close: @MainActor () -> Void = {}

    init(
        geometry: NotchGeometry,
        nowPlaying: NowPlayingService,
        battery: BatteryService,
        shelf: Shelf,
        clipboard: ClipboardHistory,
        settings: AppSettings
    ) {
        self.geometry = geometry
        self.nowPlaying = nowPlaying
        self.battery = battery
        self.shelf = shelf
        self.clipboard = clipboard
        self.settings = settings
        shelfDragSource.onDrop = { [weak self] items in
            self?.didDragOut(items)
        }
    }

    /// Whether the open notch shows the shelf rather than now playing.
    var showsShelf: Bool {
        settings.shelfEnabled && tab == .shelf
    }

    var showsClipboard: Bool {
        settings.clipboardEnabled && tab == .clipboard
    }

    /// Puts a clipboard entry back on the pasteboard, ready to paste, and closes the notch.
    func choose(_ entry: ClipboardEntry) {
        clipboard.copy(entry)
        close()
    }

    /// Moves the clipboard selection up or down the list, staying within it.
    func moveClipboardSelection(by offset: Int) {
        let last = clipboard.entries.count - 1
        clipboardSelection = max(0, min(last, clipboardSelection + offset))
    }

    /// With nothing to choose, Return just closes the history, so the keys typed next reach the app in front.
    func chooseSelectedClipboardEntry() {
        guard clipboard.entries.indices.contains(clipboardSelection) else {
            close()
            return
        }
        choose(clipboard.entries[clipboardSelection])
    }

    func removeSelectedClipboardEntry() {
        guard clipboard.entries.indices.contains(clipboardSelection) else { return }
        clipboard.remove(clipboard.entries[clipboardSelection].id)
        moveClipboardSelection(by: 0)
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
            let contentHeight = showsClipboard ? Layout.clipboardContentHeight : Layout.openContentHeight
            return CGSize(width: Layout.openWidth, height: notch.height + contentHeight)
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

    /// The panel is sized once for the tallest open state and never resized, which keeps animations smooth.
    var windowSize: CGSize {
        CGSize(
            width: Layout.openWidth + 2 * Layout.openTopRadius + 2 * Layout.shadowPadding,
            height: geometry.notchSize.height
                + max(Layout.openContentHeight, Layout.clipboardContentHeight)
                + Layout.shadowPadding
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
