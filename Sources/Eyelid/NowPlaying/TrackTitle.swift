import AppKit

/// The title of what just started playing, shown for a moment under the closed notch. Titles too long for the notch
/// scroll by, like a ticker.
struct TrackTitle: Equatable, Identifiable {
    let id = UUID()
    let title: String
    let artist: String
    /// The width of the title and artist in one line, in points.
    let textWidth: CGFloat

    static let fontSize: CGFloat = 12
    /// Room between the end of the text and its next copy while it scrolls.
    static let gap: CGFloat = 36
    /// Slow enough to read along.
    static let scrollSpeed: CGFloat = 30
    /// Faster still for very long titles, so one pass fits in `maxDuration`.
    static let maxDuration: TimeInterval = 12
    /// A title that fits stays this long.
    static let shortDuration: TimeInterval = 3.5
    /// A scrolling title waits this long before it starts, so the start can be read.
    static let lead: TimeInterval = 1.5
    /// And stays this long after its first pass.
    static let tail: TimeInterval = 0.8

    init(title: String, artist: String) {
        self.title = title
        self.artist = artist
        textWidth = Self.measure(title: title, artist: artist)
    }

    init(track: NowPlayingTrack) {
        self.init(title: track.title, artist: track.artist)
    }

    /// Shown after the title, dimmer.
    var detail: String? {
        artist.isEmpty ? nil : artist
    }

    static let separator = "  ·  "

    /// Measured with the fonts the notch draws in, which are the same system fonts as SwiftUI's.
    static func measure(title: String, artist: String) -> CGFloat {
        let text = NSMutableAttributedString(
            string: title,
            attributes: [.font: NSFont.systemFont(ofSize: fontSize, weight: .semibold)]
        )
        if !artist.isEmpty {
            text.append(NSAttributedString(
                string: separator + artist,
                attributes: [.font: NSFont.systemFont(ofSize: fontSize, weight: .medium)]
            ))
        }
        return ceil(text.size().width)
    }

    // MARK: - Scrolling

    func scrolls(in width: CGFloat) -> Bool {
        textWidth > width
    }

    /// The distance of one pass: the text and the gap after it, where the next copy starts.
    var loopLength: CGFloat {
        textWidth + Self.gap
    }

    /// Points a second.
    var speed: CGFloat {
        let time = Self.maxDuration - Self.lead - Self.tail
        return max(Self.scrollSpeed, loopLength / time)
    }

    /// How long the title stays: a moment if it fits, otherwise one full pass.
    func duration(in width: CGFloat) -> TimeInterval {
        guard scrolls(in: width) else { return Self.shortDuration }
        return Self.lead + TimeInterval(loopLength / speed) + Self.tail
    }

    /// How far the text has scrolled to the left, `elapsed` seconds after it showed.
    func offset(after elapsed: TimeInterval, in width: CGFloat) -> CGFloat {
        guard scrolls(in: width), elapsed > Self.lead else { return 0 }
        let distance = CGFloat(elapsed - Self.lead) * speed
        return distance.truncatingRemainder(dividingBy: loopLength)
    }

    // MARK: - When to show it

    /// Something started playing: a new track, or the same one after a pause. Not a track that keeps playing, whose
    /// position or artwork changed.
    static func isWorthShowing(from previous: NowPlayingTrack?, to current: NowPlayingTrack) -> Bool {
        guard current.isPlaying, !current.title.isEmpty else { return false }
        guard let previous, previous.isPlaying else { return true }
        return previous.title != current.title || previous.artist != current.artist || previous.album != current.album
    }
}
