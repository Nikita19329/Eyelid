import Foundation
import SwiftUI
import Testing
@testable import Eyelid

@Suite("Notch shape")
struct NotchShapeTests {
    @Test(arguments: [
        CGRect(x: 0, y: 0, width: 197, height: 32),
        CGRect(x: 40, y: 0, width: 468, height: 140),
    ])
    func outlineFillsItsFrame(rect: CGRect) {
        let shape = NotchShape(topCornerRadius: 6, bottomCornerRadius: 10)

        #expect(shape.path(in: rect).boundingRect == rect)
    }

    @Test func animatesBothRadiiAndTheLowerLid() {
        var shape = NotchShape(topCornerRadius: 6, bottomCornerRadius: 10)

        shape.animatableData = AnimatablePair(AnimatablePair(14, 26), 5)

        #expect(shape.topCornerRadius == 14)
        #expect(shape.bottomCornerRadius == 26)
        #expect(shape.lowerLidDepth == 5)
    }

    @Test func lowerLidHangsInTheMiddleAndLiftsTheCorners() {
        let rect = CGRect(x: 0, y: 0, width: 281, height: 56)
        let path = NotchShape(topCornerRadius: 6, bottomCornerRadius: 10, lowerLidDepth: 5).path(in: rect)

        // The middle still reaches the bottom, so the outline fills its frame.
        #expect(path.boundingRect == rect)
        #expect(path.contains(CGPoint(x: rect.midX, y: rect.maxY - 1)))
        // Near a bottom corner, the curve has risen.
        #expect(!path.contains(CGPoint(x: 6 + 12, y: rect.maxY - 2)))
    }
}

@Suite("mediaremote-adapter client")
struct MediaRemoteAdapterTests {
    private let adapter = MediaRemoteAdapter(
        script: URL(filePath: "/App/Contents/Resources/mediaremote-adapter.pl"),
        framework: URL(filePath: "/App/Contents/Frameworks/MediaRemoteAdapter.framework")
    )

    @Test func runsInsideApplesPerl() {
        // MediaRemote only answers entitled Apple processes, and /usr/bin/perl is one of them.
        let process = adapter.makeProcess(arguments: ["stream", "--no-diff"])

        #expect(process.executableURL?.path == "/usr/bin/perl")
        #expect(process.arguments == [
            "/App/Contents/Resources/mediaremote-adapter.pl",
            "/App/Contents/Frameworks/MediaRemoteAdapter.framework",
            "stream",
            "--no-diff",
        ])
    }

    @Test func commandsUseMediaRemoteIDs() {
        // The adapter forwards these numbers to MRMediaRemoteSendCommand as they are.
        #expect(MediaRemoteAdapter.Command.play.rawValue == 0)
        #expect(MediaRemoteAdapter.Command.pause.rawValue == 1)
        #expect(MediaRemoteAdapter.Command.togglePlayPause.rawValue == 2)
        #expect(MediaRemoteAdapter.Command.nextTrack.rawValue == 4)
        #expect(MediaRemoteAdapter.Command.previousTrack.rawValue == 5)
    }
}
