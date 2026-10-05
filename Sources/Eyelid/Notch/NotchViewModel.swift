import AppKit
import Observation

@MainActor
@Observable
final class NotchViewModel {
    enum State {
        case closed
        case open
    }

    enum Layout {
        static let openWidth: CGFloat = 440
        /// Height of the open notch below the hardware notch strip.
        static let openContentHeight: CGFloat = 108
        /// Extra room on each side of the closed notch for the live activity.
        static let activitySideWidth: CGFloat = 42
        /// Transparent margin around the open notch so its shadow is not clipped.
        static let shadowPadding: CGFloat = 40

        static let closedTopRadius: CGFloat = 6
        static let closedBottomRadius: CGFloat = 10
        static let openTopRadius: CGFloat = 14
        static let openBottomRadius: CGFloat = 26
    }

    var state: State = .closed
    var geometry: NotchGeometry
    let nowPlaying: NowPlayingService
    let settings: AppSettings

    init(geometry: NotchGeometry, nowPlaying: NowPlayingService, settings: AppSettings) {
        self.geometry = geometry
        self.nowPlaying = nowPlaying
        self.settings = settings
    }

    /// Whether the closed notch grows sideways to show artwork and an equalizer.
    var showsActivity: Bool {
        settings.showsLiveActivity && nowPlaying.track?.isPlaying == true
    }

    /// Size of the notch body, excluding the ears.
    var bodySize: CGSize {
        let notch = geometry.notchSize
        switch state {
        case .open:
            return CGSize(width: Layout.openWidth, height: notch.height + Layout.openContentHeight)
        case .closed:
            let extra = showsActivity ? 2 * Layout.activitySideWidth : 0
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

    /// Area in global coordinates where the cursor opens the notch, or keeps it open.
    /// The open area is more forgiving, so the notch does not flicker at its edge.
    var hoverRect: CGRect {
        let size = bodySize
        let rect = CGRect(
            x: geometry.notchMidX - size.width / 2,
            y: geometry.screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        let margin: CGFloat = state == .open ? 12 : 4
        return rect.insetBy(dx: -margin, dy: -margin)
    }
}
