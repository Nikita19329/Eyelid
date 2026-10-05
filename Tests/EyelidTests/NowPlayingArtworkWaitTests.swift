import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Eyelid

/// macOS reports a new track a moment before its artwork. The notch shouldn't blink to the placeholder in between,
/// and the title should show in the new artwork's colors.
@MainActor
@Suite("Artwork on its way")
struct NowPlayingArtworkWaitTests {
    private final class Starts {
        var titles: [String] = []
    }

    private func png(red: CGFloat, green: CGFloat, blue: CGFloat) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: red, green: green, blue: blue, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func snapshot(_ title: String, playing: Bool = true, artwork: Data? = nil) throws -> NowPlayingSnapshot {
        let json = #"{"title":"\#(title)","artist":"Artist","playing":\#(playing)}"#
        let payload = try JSONDecoder().decode(AdapterStreamMessage.Payload.self, from: Data(json.utf8))
        var snapshot = try #require(NowPlayingSnapshot(payload: payload))
        snapshot.artworkData = artwork
        snapshot.artwork = artwork.flatMap(Artwork.init(data:))
        return snapshot
    }

    private func service(_ starts: Starts) -> NowPlayingService {
        let service = NowPlayingService(artworkGrace: 0.06)
        service.onPlaybackStart = { track in
            starts.titles.append(track.title)
        }
        return service
    }

    /// What Yandex Music sends as the track changes: no artwork, the previous track's, none again, then its own.
    @Test func keepsThePreviousArtworkUntilTheNewTracksOwnComes() throws {
        let starts = Starts()
        let service = service(starts)
        let red = try png(red: 0.9, green: 0.1, blue: 0.1)
        let blue = try png(red: 0.1, green: 0.2, blue: 0.9)
        service.apply(try snapshot("One", artwork: red))
        #expect(!service.isAwaitingArtwork)

        service.apply(try snapshot("Two"))
        // The notch reacts right away, and the title waits for the artwork.
        #expect(starts.titles == ["One", "Two"])
        #expect(service.isAwaitingArtwork)
        for update in [try snapshot("Two", artwork: red), try snapshot("Two")] {
            service.apply(update)
            #expect(service.isAwaitingArtwork)
            #expect((service.track?.artworkColor?.red ?? 0) > 0.8)
        }

        service.apply(try snapshot("Two", artwork: blue))

        #expect(!service.isAwaitingArtwork)
        #expect((service.track?.artworkColor?.blue ?? 0) > 0.8)
        #expect(starts.titles == ["One", "Two"])
    }

    @Test func trackWithoutArtworkShowsOnceTheWaitIsOver() async throws {
        let starts = Starts()
        let service = service(starts)
        service.apply(try snapshot("One", artwork: try png(red: 0.9, green: 0.1, blue: 0.1)))

        service.apply(try snapshot("Two"))
        try await Task.sleep(for: .milliseconds(250))

        #expect(!service.isAwaitingArtwork)
        #expect(service.track?.title == "Two")
        #expect(service.track?.artwork == nil)
        #expect(service.track?.artworkColor == nil)
    }

    @Test func nextTrackOfTheSameAlbumKeepsItsArtwork() async throws {
        let starts = Starts()
        let service = service(starts)
        let cover = try png(red: 0.2, green: 0.8, blue: 0.3)
        service.apply(try snapshot("One", artwork: cover))

        service.apply(try snapshot("Two"))
        service.apply(try snapshot("Two", artwork: cover))
        try await Task.sleep(for: .milliseconds(250))

        #expect(!service.isAwaitingArtwork)
        #expect(service.track?.artwork != nil)
        #expect((service.track?.artworkColor?.green ?? 0) > 0.7)
    }

    @Test func resumingShowsTheTitleRightAway() throws {
        let starts = Starts()
        let service = service(starts)
        let cover = try png(red: 0.9, green: 0.6, blue: 0.1)

        service.apply(try snapshot("One", artwork: cover))
        service.apply(try snapshot("One", playing: false, artwork: cover))
        service.apply(try snapshot("One", artwork: cover))

        #expect(starts.titles == ["One", "One"])
        #expect(!service.isAwaitingArtwork)
    }

    @Test func updatesWithoutArtworkLeaveTheTrackAsItIs() throws {
        let starts = Starts()
        let service = service(starts)
        service.apply(try snapshot("One", artwork: try png(red: 0.9, green: 0.1, blue: 0.1)))

        service.apply(try snapshot("One"))

        #expect(service.track?.artwork != nil)
    }
}
