/// Tells, from the tracks macOS reports one after another, when something starts playing: a new track, or the last
/// one after a real pause. Not a track that plays on, nor one that was seeked, which pauses for a moment.
///
/// Only starts that were reported count: a muted YouTube preview, which plays and pauses as the pointer comes and
/// goes but is never heard, never was. Opening that video is then its start.
struct PlaybackStarts {
    /// A track as far as starts go: what it is, not where it's at.
    struct Item: Equatable {
        let title: String
        let artist: String
        let album: String

        init(_ track: NowPlayingTrack) {
            title = track.title
            artist = track.artist
            album = track.album
        }
    }

    /// The same track playing on after a pause shorter than this isn't a start: seeking pauses for a moment, and so
    /// does buffering.
    static let shortPause: Duration = .seconds(10)

    /// The track whose start was reported last, and since when it's paused, if it is.
    private(set) var reported: Item?
    private(set) var reportedPausedAt: ContinuousClock.Instant?

    /// Whether this update is a start. One that isn't reported yet stays a start until it is.
    mutating func isStart(_ track: NowPlayingTrack?, at now: ContinuousClock.Instant) -> Bool {
        guard let track, !track.title.isEmpty else { return false }
        let item = Item(track)
        guard track.isPlaying else {
            if reported == item, reportedPausedAt == nil {
                reportedPausedAt = now
            }
            return false
        }
        guard reported == item else { return true }
        guard let pausedAt = reportedPausedAt else { return false }
        reportedPausedAt = nil
        return now - pausedAt >= Self.shortPause
    }

    /// Records a reported start, so the same track playing on isn't another.
    mutating func didReport(_ track: NowPlayingTrack) {
        reported = Item(track)
        reportedPausedAt = nil
    }
}
