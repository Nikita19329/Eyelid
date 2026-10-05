import AppKit
import CoreText

/// What started playing, running along the lower lid of the notch: in from its right corner, out at its left one.
///
/// The text itself comes from the track as it is at each moment, so a title that arrives a little late still shows.
struct TrackTitle: Equatable, Identifiable {
    let id = UUID()
    /// When the lid opened. The text starts on its way in from the right corner then.
    let startedAt: Date

    init(startedAt: Date = .now) {
        self.startedAt = startedAt
    }

    static let fontSize: CGFloat = 12
    static let separator = "  ·  "
    /// Slow enough to read along, in points a second.
    static let speed: CGFloat = 45
    /// Long titles run faster, so a pass takes this long at most.
    static let maxDuration: TimeInterval = 12
    /// The text starts this far along from the right end, where the lid is still too shallow to show it. So it shows
    /// about 0.6 s in: after the lid has opened, and after a title that came early has the rest of its track.
    static let lead: CGFloat = 22

    /// How fast a text this wide runs along a path this long.
    static func speed(textWidth: CGFloat, pathLength: CGFloat) -> CGFloat {
        max(speed, (pathLength - lead + textWidth) / maxDuration)
    }

    /// How long a text this wide takes to come in at the right end of the path and leave at the left one.
    static func duration(textWidth: CGFloat, pathLength: CGFloat) -> TimeInterval {
        TimeInterval((pathLength - lead + textWidth) / speed(textWidth: textWidth, pathLength: pathLength))
    }

    /// Where the start of the text is along the path, from its left end, `elapsed` seconds in. It starts by the right
    /// end and moves left, past the left end.
    static func textStart(after elapsed: TimeInterval, textWidth: CGFloat, pathLength: CGFloat) -> CGFloat {
        pathLength - lead - CGFloat(max(elapsed, 0)) * speed(textWidth: textWidth, pathLength: pathLength)
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

/// The title and artist in one line, measured character by character, so each can be placed on its own along the lid.
struct TitleLine: Equatable {
    struct Character: Equatable {
        let text: String
        /// From the start of the line, in points.
        let offset: CGFloat
        let width: CGFloat
        /// The artist, shown dimmer than the title.
        let isDetail: Bool
    }

    let title: String
    let artist: String
    let characters: [Character]
    let width: CGFloat

    init(title: String, artist: String) {
        self.title = title
        self.artist = artist

        let text = NSMutableAttributedString(
            string: title,
            attributes: [.font: NSFont.systemFont(ofSize: TrackTitle.fontSize, weight: .semibold)]
        )
        if !artist.isEmpty {
            text.append(NSAttributedString(
                string: TrackTitle.separator + artist,
                attributes: [.font: NSFont.systemFont(ofSize: TrackTitle.fontSize, weight: .medium)]
            ))
        }

        // One layout of the whole line, so kerning between characters counts.
        let line = CTLineCreateWithAttributedString(text)
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let string = text.string as NSString
        let titleLength = (title as NSString).length
        var characters: [Character] = []
        var index = 0
        while index < string.length {
            let range = string.rangeOfComposedCharacterSequence(at: index)
            let start = CTLineGetOffsetForStringIndex(line, range.location, nil)
            let end = range.upperBound < string.length
                ? CTLineGetOffsetForStringIndex(line, range.upperBound, nil)
                : width
            characters.append(Character(
                text: string.substring(with: range),
                offset: start,
                width: max(end - start, 0),
                isDetail: range.location >= titleLength
            ))
            index = range.upperBound
        }
        self.characters = characters
        self.width = ceil(width)
    }
}

/// The line the text runs along: the bottom of the lower lid, raised by `inset`, from its left corner to its right one.
/// Coordinates start at the top left of the lid, under the hardware notch.
struct LidCurve {
    struct Point {
        let position: CGPoint
        /// The direction of the curve there, in radians, as it runs from left to right.
        let angle: CGFloat
    }

    let length: CGFloat
    private let samples: [(distance: CGFloat, point: CGPoint)]

    init(width: CGFloat, depth: CGFloat, inset: CGFloat) {
        let (start, control1, control2, end) = Almond.leftHalf(from: 0, to: width / 2, top: 0, depth: depth)
        var points: [CGPoint] = []
        let steps = 60
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let u = 1 - t
            points.append(CGPoint(
                x: u * u * u * start.x + 3 * u * u * t * control1.x + 3 * u * t * t * control2.x + t * t * t * end.x,
                y: u * u * u * start.y + 3 * u * u * t * control1.y + 3 * u * t * t * control2.y + t * t * t * end.y
            ))
        }
        // The right half mirrors the left one.
        points += points.dropLast().reversed().map { CGPoint(x: width - $0.x, y: $0.y) }

        var samples: [(CGFloat, CGPoint)] = []
        var distance: CGFloat = 0
        for (index, point) in points.enumerated() {
            if index > 0 {
                let previous = points[index - 1]
                distance += hypot(point.x - previous.x, point.y - previous.y)
            }
            samples.append((distance, CGPoint(x: point.x, y: point.y - inset)))
        }
        self.samples = samples
        length = distance
    }

    /// The point `distance` points along the curve from its left end, or nil off either end.
    func point(at distance: CGFloat) -> Point? {
        guard distance >= 0, distance <= length, samples.count > 1 else { return nil }
        var low = 0
        var high = samples.count - 1
        while high - low > 1 {
            let middle = (low + high) / 2
            if samples[middle].distance <= distance {
                low = middle
            } else {
                high = middle
            }
        }
        let a = samples[low]
        let b = samples[high]
        let span = b.distance - a.distance
        let fraction = span > 0 ? (distance - a.distance) / span : 0
        return Point(
            position: CGPoint(
                x: a.point.x + (b.point.x - a.point.x) * fraction,
                y: a.point.y + (b.point.y - a.point.y) * fraction
            ),
            angle: atan2(b.point.y - a.point.y, b.point.x - a.point.x)
        )
    }
}

/// The almond curve of the lower lid, shared by the notch's outline and the line its text runs along.
enum Almond {
    /// The left half of the curve, from the corner at `top` down to the middle at `top + depth`: its start, two control
    /// points and end. It leaves the corner steeply, like the corner of an eye, and flattens out at the bottom.
    static func leftHalf(from left: CGFloat, to middle: CGFloat, top: CGFloat, depth: CGFloat)
        -> (CGPoint, CGPoint, CGPoint, CGPoint) {
        let span = middle - left
        return (
            CGPoint(x: left, y: top),
            CGPoint(x: left + 0.22 * span, y: top + 0.8 * depth),
            CGPoint(x: middle - 0.5 * span, y: top + depth),
            CGPoint(x: middle, y: top + depth)
        )
    }
}
