import Foundation
import Testing
@testable import Eyelid

/// Decoding of `mediaremote-adapter stream --no-diff --micros` lines.
@Suite("Adapter stream decoding")
struct NowPlayingSnapshotTests {
    private func snapshot(fromLine line: String) throws -> NowPlayingSnapshot? {
        let message = try JSONDecoder().decode(AdapterStreamMessage.self, from: Data(line.utf8))
        return NowPlayingSnapshot(payload: message.payload)
    }

    @Test func decodesAFullPayload() throws {
        let artwork = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let line = """
            {"type":"data","diff":false,"payload":{"title":"Bird","artist":"Kwoon","album":"Large Hearts",\
            "bundleIdentifier":"ru.yandex.desktop.music","playing":true,"playbackRate":1,\
            "durationMicros":304000000,"elapsedTimeMicros":277500000,"timestampEpochMicros":1791165000000000,\
            "artworkData":"\(artwork.base64EncodedString())","artworkMimeType":"image/jpeg"}}
            """

        let snapshot = try #require(try snapshot(fromLine: line))

        #expect(snapshot.title == "Bird")
        #expect(snapshot.artist == "Kwoon")
        #expect(snapshot.album == "Large Hearts")
        #expect(snapshot.appBundleIdentifier == "ru.yandex.desktop.music")
        #expect(snapshot.isPlaying)
        #expect(snapshot.playbackRate == 1)
        #expect(snapshot.duration == 304)
        #expect(snapshot.elapsedTime == 277.5)
        #expect(snapshot.timestamp == Date(timeIntervalSince1970: 1_791_165_000))
        #expect(snapshot.artworkData == artwork)
    }

    @Test func emptyPayloadMeansNothingIsPlaying() throws {
        #expect(try snapshot(fromLine: #"{"type":"data","diff":false,"payload":{}}"#) == nil)
    }

    @Test func missingFieldsFallBackToDefaults() throws {
        let snapshot = try #require(try snapshot(fromLine: #"{"type":"data","diff":false,"payload":{"title":"Live"}}"#))

        #expect(snapshot.artist == "")
        #expect(snapshot.album == "")
        #expect(snapshot.appBundleIdentifier == nil)
        #expect(!snapshot.isPlaying)
        #expect(snapshot.playbackRate == 1)
        #expect(snapshot.duration == nil)
        #expect(snapshot.elapsedTime == nil)
        #expect(snapshot.timestamp == nil)
        #expect(snapshot.artworkData == nil)
    }

    @Test func webMediaIsAttributedToTheBrowser() throws {
        let line = """
            {"type":"data","diff":false,"payload":{"title":"Video","bundleIdentifier":"com.apple.WebKit.GPU",\
            "parentApplicationBundleIdentifier":"com.apple.Safari","playing":true}}
            """

        let snapshot = try #require(try snapshot(fromLine: line))

        #expect(snapshot.appBundleIdentifier == "com.apple.Safari")
    }

    @Test func pausedPlaybackRateDoesNotFreezeTheProgressBar() throws {
        // Players report a rate of 0 while paused. The play button flips the state before the adapter reports
        // the new rate, and a stored 0 would keep the progress bar still until then.
        let line = #"{"type":"data","diff":false,"payload":{"title":"Paused","playing":false,"playbackRate":0}}"#

        let snapshot = try #require(try snapshot(fromLine: line))

        #expect(snapshot.playbackRate == 1)
    }

    @Test func nullValuesAreTreatedAsMissing() throws {
        let line = #"{"type":"data","diff":false,"payload":{"title":"Song","artist":null,"durationMicros":null}}"#

        let snapshot = try #require(try snapshot(fromLine: line))

        #expect(snapshot.artist == "")
        #expect(snapshot.duration == nil)
    }
}
