import AppKit

struct NowPlayingTrack: Equatable {
    var title: String
    var artist: String
    var album: String
    var isPlaying: Bool
    var playbackRate: Double
    var duration: TimeInterval?
    /// Elapsed time as of `timestamp`.
    var elapsedTime: TimeInterval?
    var timestamp: Date?
    var artwork: NSImage?

    /// The app playing the media. For web media this is the browser.
    var appName: String?
    var appIcon: NSImage?
    /// The most vivid color of the artwork, if it has one.
    var artworkColor: ArtworkColor? = nil

    var subtitle: String {
        artist.isEmpty ? (appName ?? "") : artist
    }

    /// Extrapolates the elapsed time, since the adapter only reports it when the playback state changes.
    func elapsedTime(at date: Date) -> TimeInterval? {
        guard let elapsedTime else { return nil }
        guard isPlaying, let timestamp else { return elapsedTime }

        let elapsed = max(elapsedTime + date.timeIntervalSince(timestamp) * playbackRate, 0)
        if let duration, duration > 0 {
            return min(elapsed, duration)
        }
        return elapsed
    }
}

/// A decoded stream update, prepared off the main thread.
struct NowPlayingSnapshot: Sendable {
    var title: String
    var artist: String
    var album: String
    var appBundleIdentifier: String?
    var isPlaying: Bool
    var playbackRate: Double
    var duration: TimeInterval?
    var elapsedTime: TimeInterval?
    var timestamp: Date?
    /// The raw image, to tell whether the artwork changed.
    var artworkData: Data?
    /// Filled in by `NowPlayingService`, which decodes each new image once.
    var artwork: Artwork?

    /// Returns nil when nothing is playing: the adapter then sends an empty payload.
    init?(payload: AdapterStreamMessage.Payload) {
        guard let title = payload.title else { return nil }

        self.title = title
        artist = payload.artist ?? ""
        album = payload.album ?? ""
        // Web media is often reported by a helper process; the parent is the browser itself.
        appBundleIdentifier = payload.parentApplicationBundleIdentifier ?? payload.bundleIdentifier
        isPlaying = payload.playing ?? false
        playbackRate = payload.playbackRate.flatMap { $0 > 0 ? $0 : nil } ?? 1
        duration = payload.durationMicros.map { $0 / 1_000_000 }
        elapsedTime = payload.elapsedTimeMicros.map { $0 / 1_000_000 }
        timestamp = payload.timestampEpochMicros.map { Date(timeIntervalSince1970: $0 / 1_000_000) }
        artworkData = payload.artworkData.flatMap { encoded in
            encoded.utf8.count <= Artwork.maxEncodedLength ? Data(base64Encoded: encoded) : nil
        }
    }
}
