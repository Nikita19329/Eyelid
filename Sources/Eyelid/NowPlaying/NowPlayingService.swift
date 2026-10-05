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

    private func apply(_ snapshot: NowPlayingSnapshot?) {
        guard let snapshot else {
            track = nil
            artworkData = nil
            return
        }

        var artwork = track?.artwork
        var artworkColor = track?.artworkColor
        if snapshot.artworkData != artworkData {
            artworkData = snapshot.artworkData
            artwork = snapshot.artwork.map { NSImage(cgImage: $0.image, size: .zero) }
            artworkColor = snapshot.artwork?.color
        }

        let appURL = snapshot.appBundleIdentifier.flatMap {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        }

        let previous = track
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
