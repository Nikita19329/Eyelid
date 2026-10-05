import Foundation
import Testing
@testable import Eyelid

@Suite("Playback time")
struct NowPlayingTrackTests {
    private let reportedAt = Date(timeIntervalSince1970: 1_000_000)

    private func track(
        isPlaying: Bool,
        elapsedTime: TimeInterval? = 30,
        duration: TimeInterval? = 200,
        playbackRate: Double = 1,
        artist: String = "",
        appName: String? = nil
    ) -> NowPlayingTrack {
        NowPlayingTrack(
            title: "Track",
            artist: artist,
            album: "",
            isPlaying: isPlaying,
            playbackRate: playbackRate,
            duration: duration,
            elapsedTime: elapsedTime,
            timestamp: reportedAt,
            artwork: nil,
            appName: appName,
            appIcon: nil
        )
    }

    @Test func pausedTrackKeepsItsPosition() {
        let track = track(isPlaying: false)

        #expect(track.elapsedTime(at: reportedAt.addingTimeInterval(60)) == 30)
    }

    @Test func playingTrackAdvancesWithTime() {
        let track = track(isPlaying: true)

        #expect(track.elapsedTime(at: reportedAt.addingTimeInterval(10)) == 40)
    }

    @Test func playbackRateScalesTheAdvance() {
        let track = track(isPlaying: true, playbackRate: 2)

        #expect(track.elapsedTime(at: reportedAt.addingTimeInterval(10)) == 50)
    }

    @Test func stopsAtTheEnd() {
        let track = track(isPlaying: true)

        #expect(track.elapsedTime(at: reportedAt.addingTimeInterval(1_000)) == 200)
    }

    @Test func neverGoesBelowZero() {
        // The clock can be slightly behind the timestamp the player reported.
        let track = track(isPlaying: true)

        #expect(track.elapsedTime(at: reportedAt.addingTimeInterval(-100)) == 0)
    }

    @Test func liveStreamsWithoutADurationKeepCounting() {
        let track = track(isPlaying: true, duration: nil)

        #expect(track.elapsedTime(at: reportedAt.addingTimeInterval(1_000)) == 1_030)
    }

    @Test func unknownPositionStaysUnknown() {
        let track = track(isPlaying: true, elapsedTime: nil)

        #expect(track.elapsedTime(at: reportedAt.addingTimeInterval(10)) == nil)
    }

    @Test func subtitleIsTheArtist() {
        #expect(track(isPlaying: true, artist: "Kwoon", appName: "Music").subtitle == "Kwoon")
    }

    @Test func subtitleFallsBackToTheAppName() {
        #expect(track(isPlaying: true, artist: "", appName: "Firefox").subtitle == "Firefox")
        #expect(track(isPlaying: true, artist: "", appName: nil).subtitle == "")
    }

    @MainActor
    @Test(arguments: zip(
        [0, 5.9, 65, 599, 3_600, 3_723, -3] as [TimeInterval],
        ["0:00", "0:05", "1:05", "9:59", "1:00:00", "1:02:03", "0:00"]
    ))
    func formatsTimes(seconds: TimeInterval, expected: String) {
        #expect(PlaybackProgressView.format(seconds) == expected)
    }
}
