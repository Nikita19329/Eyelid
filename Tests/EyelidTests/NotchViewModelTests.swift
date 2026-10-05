import Foundation
import Testing
@testable import Eyelid

@MainActor
@Suite("Notch layout")
struct NotchViewModelTests {
    /// A 14-inch MacBook Pro: 1512×982 points with a 185×32 notch in the middle.
    private let geometry = NotchGeometry(
        notchSize: CGSize(width: 185, height: 32),
        notchMidX: 756,
        screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982)
    )

    private func makeModel() -> NotchViewModel {
        NotchViewModel(geometry: geometry, nowPlaying: NowPlayingService(), settings: AppSettings(defaults: InMemorySettingsStore()))
    }

    @Test func closedNotchMatchesTheHardwareNotch() {
        let model = makeModel()

        #expect(model.bodySize == CGSize(width: 185, height: 32))
        #expect(model.topRadius == NotchViewModel.Layout.closedTopRadius)
        #expect(model.bottomRadius == NotchViewModel.Layout.closedBottomRadius)
    }

    @Test func openNotchGrowsBelowTheHardwareNotch() {
        let model = makeModel()
        model.state = .open

        #expect(model.bodySize == CGSize(width: 440, height: 32 + 108))
        #expect(model.topRadius == NotchViewModel.Layout.openTopRadius)
    }

    @Test func windowFitsTheOpenNotchAndItsShadow() {
        let model = makeModel()
        let window = model.windowSize
        model.state = .open
        let open = model.bodySize

        #expect(window.width >= open.width + 2 * model.topRadius)
        #expect(window.height > open.height)
    }

    @Test func noLiveActivityWithoutATrack() {
        #expect(!makeModel().showsActivity)
    }

    @Test func pointerOnTheNotchOpensIt() {
        let model = makeModel()

        #expect(model.hoverRect.contains(CGPoint(x: 756, y: 981)))
        #expect(model.hoverRect.contains(CGPoint(x: 756 - 92, y: 960)))
    }

    @Test func pointerBesideOrBelowTheNotchDoesNot() {
        let model = makeModel()

        #expect(!model.hoverRect.contains(CGPoint(x: 600, y: 981)))
        #expect(!model.hoverRect.contains(CGPoint(x: 756, y: 900)))
    }

    @Test func openNotchStaysOpenAcrossItsWholeArea() {
        // The open area is larger than the closed one, so the notch doesn't flicker at its edge.
        let model = makeModel()
        let belowTheHardwareNotch = CGPoint(x: 756, y: 982 - 100)
        #expect(!model.hoverRect.contains(belowTheHardwareNotch))

        model.state = .open

        #expect(model.hoverRect.contains(belowTheHardwareNotch))
        #expect(model.hoverRect.contains(CGPoint(x: 756 - 225, y: 982 - 145)))
        #expect(!model.hoverRect.contains(CGPoint(x: 756, y: 982 - 200)))
    }
}
