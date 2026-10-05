import AppKit
import os

private let logger = Logger(subsystem: "io.github.nikita19329.eyelid", category: "Notch")

/// Owns the notch panel: keeps it pinned to the notch and opens or closes it as the cursor moves.
@MainActor
final class NotchWindowController {
    private let panel = NotchPanel()
    private let model: NotchViewModel
    private let settings: AppSettings
    private var mouseMonitors: [Any] = []
    private var openTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var batteryEventTask: Task<Void, Never>?
    private var hudTask: Task<Void, Never>?
    /// The drag pasteboard changes when a drag starts, which tells drags apart from other mouse moves.
    private var dragPasteboardChangeCount = NSPasteboard(name: .drag).changeCount

    init(nowPlaying: NowPlayingService, battery: BatteryService, shelf: Shelf, hud: HUDService, settings: AppSettings) {
        self.settings = settings
        let screen = NotchGeometry.preferredScreen(displayID: settings.displayID) ?? NSScreen.screens[0]
        model = NotchViewModel(
            geometry: NotchGeometry(screen: screen),
            nowPlaying: nowPlaying,
            battery: battery,
            shelf: shelf,
            settings: settings
        )

        let hostingView = NotchHostingView(rootView: NotchView(model: model))
        hostingView.sizingOptions = []
        let dropView = NotchDropView(content: hostingView)
        panel.contentView = dropView
        dropView.delegate = self

        updateFrame()
        panel.orderFrontRegardless()

        installMouseMonitors()
        observeDisplayPreference()
        battery.onEvent = { [weak self] event in
            self?.show(event)
        }
        hud.onEvent = { [weak self] event in
            self?.show(event)
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateScreen()
            }
        }
    }

    // MARK: - Placement

    private func observeDisplayPreference() {
        withObservationTracking {
            _ = settings.displayID
        } onChange: { [weak self] in
            // `onChange` runs before the new value is stored, so read it on the next turn of the main actor.
            Task { @MainActor in
                self?.updateScreen()
                self?.observeDisplayPreference()
            }
        }
    }

    private func updateScreen() {
        guard let screen = NotchGeometry.preferredScreen(displayID: settings.displayID) else { return }
        model.geometry = NotchGeometry(screen: screen)
        updateFrame()
    }

    private func updateFrame() {
        let geometry = model.geometry
        let size = model.windowSize
        let frame = CGRect(
            x: geometry.notchMidX - size.width / 2,
            y: geometry.screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        panel.setFrame(frame, display: true)
    }

    // MARK: - Volume and brightness

    private func show(_ event: HUDEvent) {
        model.hud = event
        // Holding a key repeats it, so the HUD stays until the last press plus the duration.
        hudTask?.cancel()
        hudTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(NotchViewModel.Layout.hudDuration))
            guard !Task.isCancelled else { return }
            self?.model.hud = nil
        }
    }

    // MARK: - Battery

    private func show(_ event: BatteryEvent) {
        logger.debug("Battery event: \(String(describing: event), privacy: .public)")
        guard settings.batteryActivityEnabled else { return }

        model.batteryEvent = event
        batteryEventTask?.cancel()
        batteryEventTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(NotchViewModel.Layout.batteryEventDuration))
            guard !Task.isCancelled else { return }
            self?.model.batteryEvent = nil
        }
    }

    // MARK: - Hover

    private func installMouseMonitors() {
        // Mouse events, unlike key events, can be observed without the Accessibility permission.
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .leftMouseDragged, .leftMouseUp]

        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] event in
            let type = event.type
            MainActor.assumeIsolated {
                self?.handleMouse(type)
            }
        }) {
            mouseMonitors.append(global)
        }

        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
            let type = event.type
            MainActor.assumeIsolated {
                self?.handleMouse(type)
            }
            return event
        }) {
            mouseMonitors.append(local)
        }
    }

    private func handleMouse(_ type: NSEvent.EventType) {
        switch type {
        case .leftMouseDown:
            dragPasteboardChangeCount = NSPasteboard(name: .drag).changeCount
        case .leftMouseDragged:
            noticeFileDrag()
        case .leftMouseUp:
            model.isDraggingFiles = false
        default:
            break
        }
        updateHover()
    }

    /// Notices files being dragged, so the notch opens to the shelf for them, and opens from a little farther away.
    private func noticeFileDrag() {
        guard settings.shelfEnabled, !model.isDraggingFiles else { return }
        let pasteboard = NSPasteboard(name: .drag)
        guard pasteboard.changeCount != dragPasteboardChangeCount else { return }
        dragPasteboardChangeCount = pasteboard.changeCount
        model.isDraggingFiles = ShelfDrop.carriesFiles(pasteboard.types)
    }

    private func updateHover() {
        // The mouse-up that ends a drag can go unseen, for example when it ends on the notch.
        if model.isDraggingFiles, NSEvent.pressedMouseButtons & 1 == 0 {
            model.isDraggingFiles = false
        }

        let isInside = model.hoverRect.contains(NSEvent.mouseLocation)
        switch (model.state, isInside) {
        case (.closed, true):
            scheduleOpen()
        case (.closed, false):
            openTask?.cancel()
            openTask = nil
        case (.open, false):
            close()
        case (.open, true):
            break
        }
    }

    private func scheduleOpen() {
        let delay = settings.openDelay
        guard delay > 0 else {
            open()
            return
        }
        guard openTask == nil else { return }

        // Leaving the notch before the delay is up cancels the task in `updateHover`.
        openTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.open()
        }
    }

    private func open() {
        logger.debug("Opened")
        openTask?.cancel()
        openTask = nil
        if settings.shelfEnabled {
            if model.isDraggingFiles {
                model.tab = .shelf
            }
            model.shelf.refresh()
        }
        model.state = .open
        panel.ignoresMouseEvents = false
        if settings.hapticsEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }

        // While the cursor is over the panel, global monitors go quiet, so poll to notice it leaving.
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                self?.updateHover()
            }
        }
    }

    private func close() {
        logger.debug("Closed")
        model.state = .closed
        model.isDropTargeted = false
        panel.ignoresMouseEvents = true
        pollTask?.cancel()
        pollTask = nil
    }
}

// MARK: - Shelf

extension NotchWindowController: NotchDropDelegate {
    func dropOperation(for drag: any NSDraggingInfo) -> NSDragOperation {
        let operation = acceptedOperation(for: drag)
        model.isDropTargeted = operation != []
        if operation != [] {
            model.tab = .shelf
        }
        return operation
    }

    func dragDidExit() {
        model.isDropTargeted = false
    }

    func performDrop(_ drag: any NSDraggingInfo) -> Bool {
        model.isDropTargeted = false
        model.isDraggingFiles = false
        guard acceptedOperation(for: drag) != [] else { return false }

        let received = ShelfDrop.receive(drag.draggingPasteboard, into: model.shelf)
        logger.debug("Dropped files on the shelf: \(received, privacy: .public)")
        if received, settings.hapticsEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        return received
    }

    private func acceptedOperation(for drag: any NSDraggingInfo) -> NSDragOperation {
        let location = panel.convertPoint(toScreen: drag.draggingLocation)
        guard settings.shelfEnabled,
              model.state == .open,
              // Files dragged out of the shelf come from Eyelid itself, and have nowhere else to go in it.
              drag.draggingSource == nil,
              ShelfDrop.carriesFiles(drag.draggingPasteboard.types),
              // The panel is larger than the notch, to make room for its shadow.
              model.bodyRect.contains(location)
        else { return [] }

        // The shelf only keeps a reference, so the files stay where they are, but "copy" is what apps that promise
        // files expect, and what shows the plus on the pointer.
        let offered = drag.draggingSourceOperationMask
        return [.copy, .generic, .link].first { offered.contains($0) } ?? []
    }
}
