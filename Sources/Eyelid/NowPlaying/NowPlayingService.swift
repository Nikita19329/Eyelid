import AppKit
import Observation
import os

private let logger = Logger(subsystem: "io.github.satis-ku.eyelid", category: "NowPlaying")

/// Keeps `track` in sync with whatever macOS reports as now playing, from any app.
@MainActor
@Observable
final class NowPlayingService {
    private(set) var track: NowPlayingTrack?
    /// Called when something starts playing: a new track, or the same one after a pause.
    @ObservationIgnored var onPlaybackStart: (@MainActor (NowPlayingTrack) -> Void)?

    @ObservationIgnored private let adapter = MediaRemoteAdapter.locate()
    @ObservationIgnored private var process: Process?
    @ObservationIgnored private var readTask: Task<Void, Never>?
    @ObservationIgnored private var artworkData: Data?
    @ObservationIgnored private var isRunning = false
    /// macOS reports a new track a moment before its artwork, and some apps resend the previous track's artwork first:
    /// Yandex Music sends none, the old one, none again, and the new one about 0.65 s after the track changed. For this
    /// long the notch keeps the previous artwork rather than blinking through those.
    @ObservationIgnored let artworkGrace: TimeInterval
    /// Whether the artwork of a new track is on its way. The title under the notch stays hidden until then, so it shows
    /// in the colors of the new artwork from the start.
    private(set) var isAwaitingArtwork = false
    @ObservationIgnored private var artworkWait: Task<Void, Never>?
    /// The artwork shown when the track changed. Getting it again doesn't end the wait.
    @ObservationIgnored private var replacedArtworkData: Data?
    /// What the latest update brought, which stays when the wait runs out.
    @ObservationIgnored private var latestArtwork: (data: Data?, artwork: Artwork?) = (nil, nil)

    init(artworkGrace: TimeInterval = 1) {
        self.artworkGrace = artworkGrace
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        launchStream()
    }

    func stop() {
        isRunning = false
        readTask?.cancel()
        readTask = nil
        process?.terminate()
        process = nil
    }

    func send(_ command: MediaRemoteAdapter.Command) {
        adapter?.send(command)

        // Flip the play/pause button right away; the stream confirms the new state shortly after.
        if command == .togglePlayPause, var updated = track {
            let now = Date()
            updated.elapsedTime = updated.elapsedTime(at: now)
            updated.timestamp = now
            updated.isPlaying.toggle()
            track = updated
        }
    }

    // MARK: - Stream

    private func launchStream() {
        guard let adapter else {
            logger.error("mediaremote-adapter not found, now playing is disabled")
            return
        }

        let process = adapter.makeProcess(arguments: ["stream", "--no-diff", "--micros", "--debounce=100"])
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            Task { @MainActor in
                self?.streamDidExit(status: status)
            }
        }

        do {
            try process.run()
        } catch {
            logger.error("Failed to start mediaremote-adapter: \(error.localizedDescription)")
            return
        }
        self.process = process

        let output = pipe.fileHandleForReading
        readTask = Task.detached(priority: .utility) { [weak self] in
            let decoder = JSONDecoder()
            // Updates repeat the artwork, so each new image is decoded once, here and not on the main actor.
            var decoded: (data: Data, artwork: Artwork?)?
            do {
                for try await line in output.bytes.lines {
                    guard let message = try? decoder.decode(AdapterStreamMessage.self, from: Data(line.utf8)),
                          message.type == "data"
                    else { continue }

                    var snapshot = NowPlayingSnapshot(payload: message.payload)
                    if let data = snapshot?.artworkData {
                        if decoded?.data != data {
                            decoded = (data, Artwork(data: data))
                        }
                        snapshot?.artwork = decoded?.artwork
                    }
                    await self?.apply(snapshot)
                }
            } catch {
                // The pipe closes when the adapter exits; `streamDidExit` takes care of restarting it.
            }
        }
    }

    private func streamDidExit(status: Int32) {
        process = nil
        guard isRunning else { return }

        logger.warning("mediaremote-adapter exited with status \(status), restarting")
        track = nil
        artworkData = nil
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, isRunning, process == nil else { return }
            launchStream()
        }
    }

    /// Internal rather than private for the tests.
    func apply(_ snapshot: NowPlayingSnapshot?) {
        guard let snapshot else {
            track = nil
            artworkData = nil
            endArtworkWait()
            return
        }

        let previous = track
        let isNewItem = previous.map {
            $0.title != snapshot.title || $0.artist != snapshot.artist || $0.album != snapshot.album
        } ?? true
        if isNewItem {
            beginArtworkWait()
        }

        var artwork = previous?.artwork
        var artworkColor = previous?.artworkColor
        if isAwaitingArtwork {
            latestArtwork = (snapshot.artworkData, snapshot.artwork)
            if let data = snapshot.artworkData, data != replacedArtworkData {
                // The new track's own artwork.
                (artwork, artworkColor) = use(data, snapshot.artwork)
                endArtworkWait()
            }
        } else if let data = snapshot.artworkData, data != artworkData {
            // New artwork for the same track. Updates without any are left out: they come and go as tracks change.
            (artwork, artworkColor) = use(data, snapshot.artwork)
        }

        let appURL = snapshot.appBundleIdentifier.flatMap {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        }

        let current = NowPlayingTrack(
            title: snapshot.title,
            artist: snapshot.artist,
            album: snapshot.album,
            isPlaying: snapshot.isPlaying,
            playbackRate: snapshot.playbackRate,
            duration: snapshot.duration,
            elapsedTime: snapshot.elapsedTime,
            timestamp: snapshot.timestamp,
            artwork: artwork,
            appName: appURL.flatMap { FileManager.default.displayName(atPath: $0.path).replacing(".app", with: "") },
            appIcon: appURL.flatMap { Self.standardRangeIcon(forFile: $0.path) },
            artworkColor: artworkColor
        )
        track = current
        if TrackTitle.isWorthShowing(from: previous, to: current) {
            onPlaybackStart?(current)
        }
    }

    /// Shows this artwork from now on.
    private func use(_ data: Data?, _ decoded: Artwork?) -> (NSImage?, ArtworkColor?) {
        artworkData = data
        return (decoded.map { NSImage(cgImage: $0.image, size: .zero) }, decoded?.color)
    }

    // MARK: - Artwork on its way

    private func beginArtworkWait() {
        replacedArtworkData = artworkData
        latestArtwork = (nil, nil)
        isAwaitingArtwork = true
        artworkWait?.cancel()
        artworkWait = Task { [weak self, artworkGrace] in
            try? await Task.sleep(for: .seconds(artworkGrace))
            guard !Task.isCancelled else { return }
            self?.artworkWaitRanOut()
        }
    }

    /// No other artwork came: the next track of an album has the same one, or the track has none.
    private func artworkWaitRanOut() {
        artworkWait = nil
        isAwaitingArtwork = false
        guard var track else { return }
        (track.artwork, track.artworkColor) = use(latestArtwork.data, latestArtwork.artwork)
        self.track = track
    }

    private func endArtworkWait() {
        artworkWait?.cancel()
        artworkWait = nil
        isAwaitingArtwork = false
    }

    /// App icons on recent macOS are 16-bit extended-range images, and a single one of them switches
    /// SwiftUI to HDR rendering for the whole notch. A plain 8-bit sRGB copy avoids that.
    private static func standardRangeIcon(forFile path: String) -> NSImage? {
        let pixels = 64
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: pixels,
                  height: pixels,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        NSWorkspace.shared.icon(forFile: path).draw(in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()

        return context.makeImage().map { NSImage(cgImage: $0, size: NSSize(width: pixels / 2, height: pixels / 2)) }
    }
}
