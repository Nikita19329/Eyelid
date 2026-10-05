import CoreGraphics
import Foundation
import Testing
@testable import Eyelid

@Suite("Track title")
struct TrackTitleTests {
    private func track(_ title: String = "Song", artist: String = "Artist", album: String = "", isPlaying: Bool = true)
        -> NowPlayingTrack {
        NowPlayingTrack(
            title: title,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            playbackRate: 1,
            duration: 200,
            elapsedTime: 0,
            timestamp: nil,
            artwork: nil,
            appName: nil,
            appIcon: nil
        )
    }

    @Test func showsWhatStartsPlaying() {
        #expect(TrackTitle.isWorthShowing(from: nil, to: track()))
        #expect(TrackTitle.isWorthShowing(from: track(isPlaying: false), to: track()))
    }

    @Test func showsTheNextTrack() {
        #expect(TrackTitle.isWorthShowing(from: track("One"), to: track("Two")))
        #expect(TrackTitle.isWorthShowing(from: track(artist: "A"), to: track(artist: "B")))
        #expect(TrackTitle.isWorthShowing(from: track(album: "A"), to: track(album: "B")))
    }

    @Test func staysQuietWhileTheSameTrackPlaysOn() {
        var later = track()
        later.elapsedTime = 42

        #expect(!TrackTitle.isWorthShowing(from: track(), to: later))
    }

    @Test func staysQuietForPausesAndUntitledMedia() {
        #expect(!TrackTitle.isWorthShowing(from: track(), to: track(isPlaying: false)))
        #expect(!TrackTitle.isWorthShowing(from: nil, to: track("")))
    }

    @Test func shortTitleStaysPutForAMoment() {
        let title = TrackTitle(title: "Song", artist: "Artist")

        #expect(!title.scrolls(in: 240))
        #expect(title.duration(in: 240) == TrackTitle.shortDuration)
        #expect(title.offset(after: 5, in: 240) == 0)
    }

    @Test func artistMakesTheLineLonger() {
        let alone = TrackTitle(title: "Song", artist: "")
        let withArtist = TrackTitle(title: "Song", artist: "Artist")

        #expect(alone.detail == nil)
        #expect(withArtist.detail == "Artist")
        #expect(withArtist.textWidth > alone.textWidth)
    }

    @Test func longTitleScrollsOncePastItsStart() {
        let title = TrackTitle(title: String(repeating: "Long title ", count: 6), artist: "Artist")
        let width: CGFloat = 240

        #expect(title.scrolls(in: width))
        // Still at first, so the start can be read.
        #expect(title.offset(after: TrackTitle.lead / 2, in: width) == 0)
        #expect(abs(title.offset(after: TrackTitle.lead + 1, in: width) - title.speed) < 0.001)
        // One full pass brings the next copy to where the text started.
        let pass = TimeInterval(title.loopLength / title.speed)
        #expect(abs(title.offset(after: TrackTitle.lead + pass, in: width)) < 0.001
            || abs(title.offset(after: TrackTitle.lead + pass, in: width) - title.loopLength) < 0.001)
        #expect(abs(title.duration(in: width) - (TrackTitle.lead + pass + TrackTitle.tail)) < 0.001)
    }

    @Test func veryLongTitleScrollsFasterToFitInTime() {
        let title = TrackTitle(title: String(repeating: "Very long title ", count: 40), artist: "")

        #expect(title.speed > TrackTitle.scrollSpeed)
        #expect(abs(title.duration(in: 240) - TrackTitle.maxDuration) < 0.001)
    }
}

@Suite("Artwork color")
struct ArtworkColorTests {
    /// An image filled with one color, or with two side by side.
    private func image(_ colors: [(red: Double, green: Double, blue: Double)], width: Int = 64) throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: width, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let stripe = CGFloat(width) / CGFloat(colors.count)
        for (index, color) in colors.enumerated() {
            context.setFillColor(red: color.red, green: color.green, blue: color.blue, alpha: 1)
            context.fill(CGRect(x: CGFloat(index) * stripe, y: 0, width: stripe, height: 64))
        }
        return try #require(context.makeImage())
    }

    @Test func findsTheColorOfPlainArtwork() throws {
        let color = try #require(ArtworkColor.accent(of: image([(0.85, 0.1, 0.1)])))

        #expect(abs(color.red - 0.85) < 0.02)
        #expect(color.green < 0.15 && color.blue < 0.15)
    }

    @Test func prefersTheVividColorOverGray() throws {
        // Three quarters gray, one quarter blue.
        let color = try #require(ArtworkColor.accent(of: image([(0.5, 0.5, 0.5), (0.5, 0.5, 0.5), (0.5, 0.5, 0.5), (0.1, 0.3, 0.9)])))

        #expect(color.blue > 0.8)
        #expect(color.red < 0.2)
    }

    @Test func blackAndWhiteArtworkHasNoColor() throws {
        #expect(ArtworkColor.accent(of: try image([(0, 0, 0), (1, 1, 1), (0.4, 0.4, 0.4)])) == nil)
    }

    @Test(arguments: [0.0, 0.08, 0.17, 0.33, 0.5, 0.62, 0.67, 0.75, 0.83, 0.95])
    func everyHueStaysReadableOnBlack(hue: Double) {
        let deep = ArtworkColor(hsb: .init(hue: hue, saturation: 1, brightness: 0.4))

        let legible = deep.legibleOnBlack

        #expect(legible.luminance >= ArtworkColor.minLuminance)
        // Still the same hue, not washed out to white.
        #expect(abs(legible.hsb.hue - hue) < 0.02 || abs(legible.hsb.hue - hue) > 0.98)
        #expect(legible.hsb.saturation > 0.2)
    }

    @Test func convertsBetweenRGBAndHSB() {
        let color = ArtworkColor(red: 0.2, green: 0.6, blue: 0.4)

        let back = ArtworkColor(hsb: color.hsb)

        #expect(abs(back.red - 0.2) < 0.001 && abs(back.green - 0.6) < 0.001 && abs(back.blue - 0.4) < 0.001)
    }
}
