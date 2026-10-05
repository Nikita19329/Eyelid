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
        NotchViewModel(
            geometry: geometry,
            nowPlaying: NowPlayingService(),
            battery: BatteryService(),
            shelf: Shelf(store: InMemorySettingsStore(), promisedFilesDirectory: FileManager.default.temporaryDirectory),
            clipboard: ClipboardHistory(pasteboard: .withUniqueName()),
            settings: AppSettings(defaults: InMemorySettingsStore())
        )
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

    @Test func batteryEventWidensTheClosedNotch() {
        let model = makeModel()
        model.settings.showsLiveActivity = false

        model.batteryEvent = .pluggedIn(BatteryState(level: 80, isPluggedIn: true, isCharging: true))

        #expect(model.showsActivity)
        #expect(!model.showsNowPlayingActivity)
        #expect(model.bodySize.width == 185 + 2 * NotchViewModel.Layout.activitySideWidth)
    }

    @Test func hudTakesPrecedenceAndNeedsMoreRoom() {
        let model = makeModel()
        model.batteryEvent = .unplugged(BatteryState(level: 50, isPluggedIn: false, isCharging: false))

        model.hud = HUDEvent(kind: .volume, level: 0.5)

        #expect(model.showsActivity)
        #expect(model.bodySize.width == 185 + 2 * NotchViewModel.Layout.hudSideWidth)
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

    @Test func draggedFilesOpenTheNotchFromFartherAway() {
        let model = makeModel()
        let belowTheNotch = CGPoint(x: 756, y: 982 - 32 - 16)
        #expect(!model.hoverRect.contains(belowTheNotch))

        model.isDraggingFiles = true
        #expect(model.hoverRect.contains(belowTheNotch))

        model.settings.shelfEnabled = false
        #expect(!model.hoverRect.contains(belowTheNotch))
    }

    @Test func shelfTabNeedsTheShelf() {
        let model = makeModel()
        #expect(model.tab == .nowPlaying)

        model.tab = .shelf
        #expect(model.showsShelf)

        model.settings.shelfEnabled = false
        #expect(!model.showsShelf)
    }

    @Test func filesDraggedOutLeaveTheShelf() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "EyelidDragOut-\(UUID().uuidString).txt")
        try Data("taken".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let model = makeModel()
        model.shelf.add([file])
        let item = try #require(model.shelf.items.first)

        model.settings.shelfRemovesDraggedFiles = false
        model.shelfDragSource.onDrop?([item.id])
        #expect(model.shelf.items.count == 1)

        model.settings.shelfRemovesDraggedFiles = true
        model.shelfDragSource.onDrop?([item.id])
        #expect(model.shelf.items.isEmpty)
    }

    @Test func clipboardHistoryGetsATallerNotch() {
        let model = makeModel()
        model.state = .open
        model.tab = .clipboard
        #expect(model.bodySize.height == 32 + NotchViewModel.Layout.openContentHeight)

        model.settings.clipboardEnabled = true

        #expect(model.showsClipboard)
        #expect(model.bodySize.height == 32 + NotchViewModel.Layout.clipboardContentHeight)
        #expect(model.windowSize.height > model.bodySize.height)
    }

    @Test func clipboardSelectionStaysInTheList() {
        let model = makeModel()
        for text in ["one", "two", "three"] {
            model.clipboard.add(try! #require(ClipboardEntry(items: [[.string: Data(text.utf8)]])))
        }

        model.moveClipboardSelection(by: -1)
        #expect(model.clipboardSelection == 0)
        model.moveClipboardSelection(by: 5)
        #expect(model.clipboardSelection == 2)

        model.removeSelectedClipboardEntry()
        #expect(model.clipboard.entries.count == 2)
        #expect(model.clipboardSelection == 1)
    }

    @Test func choosingAnEntryClosesTheNotch() throws {
        let model = makeModel()
        var closed = false
        model.close = { closed = true }
        model.clipboard.add(try #require(ClipboardEntry(items: [[.string: Data("hello".utf8)]])))

        model.chooseSelectedClipboardEntry()

        #expect(closed)
        #expect(model.clipboard.entries.count == 1)
    }

    @Test func returnClosesAnEmptyHistory() {
        let model = makeModel()
        var closed = false
        model.close = { closed = true }

        model.chooseSelectedClipboardEntry()

        #expect(closed)
    }

    @Test func connectedHeadphonesComeBeforeABatteryEvent() {
        let model = makeModel()
        model.batteryEvent = .unplugged(BatteryState(level: 50, isPluggedIn: false, isCharging: false))

        model.headphones = HeadphonesEvent(deviceID: "airpods", name: "AirPods Pro", icon: .airpodsPro)

        #expect(model.showsActivity)
        #expect(model.bodySize.width == 185 + 2 * NotchViewModel.Layout.hudSideWidth)
    }
}
