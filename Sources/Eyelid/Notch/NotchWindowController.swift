import AppKit
import os

private let logger = Logger(subsystem: "io.github.nikita19329.eyelid", category: "Notch")

/// Owns the notch panel: keeps it pinned to the notch and opens or closes it as the cursor moves.
@MainActor
final class NotchWindowController {
    private let panel = NotchPanel()
    private let model: NotchViewModel
    private var mouseMonitors: [Any] = []
    private var pollTask: Task<Void, Never>?

    init(nowPlaying: NowPlayingService) {
        let screen = NotchGeometry.preferredScreen() ?? NSScreen.screens[0]
        model = NotchViewModel(geometry: NotchGeometry(screen: screen), nowPlaying: nowPlaying)

        let hostingView = NotchHostingView(rootView: NotchView(model: model))
        hostingView.sizingOptions = []
        panel.contentView = hostingView

        updateFrame()
        panel.orderFrontRegardless()

        installMouseMonitors()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.screenParametersDidChange()
            }
        }
    }

    private func screenParametersDidChange() {
        guard let screen = NotchGeometry.preferredScreen() else { return }
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

    // MARK: - Hover

    private func installMouseMonitors() {
        // Mouse events, unlike key events, can be observed without the Accessibility permission.
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]

        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateHover()
            }
        }) {
            mouseMonitors.append(global)
        }

        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
            MainActor.assumeIsolated {
                self?.updateHover()
            }
            return event
        }) {
            mouseMonitors.append(local)
        }
    }

    private func updateHover() {
        let isInside = model.hoverRect.contains(NSEvent.mouseLocation)
        switch (model.state, isInside) {
        case (.closed, true):
            open()
        case (.open, false):
            close()
        default:
            break
        }
    }

    private func open() {
        logger.debug("Opened")
        model.state = .open
        panel.ignoresMouseEvents = false
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)

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
        panel.ignoresMouseEvents = true
        pollTask?.cancel()
        pollTask = nil
    }
}
