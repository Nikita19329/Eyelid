import Foundation
import Testing
@testable import Eyelid

@Suite("Equalizer from the sound")
struct SpectrumAnalyzerTests {
    private let sampleRate = 48_000.0

    /// Measures a sine at this frequency and amplitude, fed in chunks the size Core Audio delivers.
    private func levels(frequency: Double, amplitude: Float) -> [Float] {
        let analyzer = SpectrumAnalyzer()
        var levels = [Float](repeating: 0, count: SpectrumAnalyzer.bands.count)
        let chunk = 512
        for start in stride(from: 0, to: 8 * chunk, by: chunk) {
            let samples = (start..<start + chunk).map { index in
                amplitude * Float(sin(2 * .pi * frequency * Double(index) / sampleRate))
            }
            _ = samples.withUnsafeBufferPointer { analyzer.add($0, sampleRate: sampleRate, into: &levels) }
        }
        return levels
    }

    @Test(arguments: [(100.0, 0), (450.0, 1), (1_500.0, 2), (6_000.0, 3)])
    func eachBandHearsItsOwnFrequencies(frequency: Double, band: Int) {
        let levels = levels(frequency: frequency, amplitude: 0.5)

        #expect(levels.indices.max { levels[$0] < levels[$1] } == band)
        // Little leaks into the other bars.
        for (index, level) in levels.enumerated() where index != band {
            #expect(level < levels[band] - 0.3)
        }
    }

    @Test func fullScaleFillsTheBarAndQuieterSoundsLess() {
        let loud = levels(frequency: 1_500, amplitude: 1)[2]
        let quieter = levels(frequency: 1_500, amplitude: 0.1)[2]

        #expect(loud > 0.9)
        // 20 dB quieter is a third of the range lower.
        #expect(abs((loud - quieter) - 20 / -SpectrumAnalyzer.floor) < 0.05)
    }

    @Test func silenceLeavesTheBarsEmpty() {
        #expect(levels(frequency: 1_000, amplitude: 0).allSatisfy { $0 == 0 })
    }

    @Test func reportsOnceAWindowIsFull() {
        let analyzer = SpectrumAnalyzer()
        var levels = [Float](repeating: 0, count: 4)
        let half = [Float](repeating: 0.1, count: SpectrumAnalyzer.windowSize / 2)

        #expect(!half.withUnsafeBufferPointer { analyzer.add($0, sampleRate: sampleRate, into: &levels) })
        #expect(half.withUnsafeBufferPointer { analyzer.add($0, sampleRate: sampleRate, into: &levels) })
        // Windows overlap by half, so the next half fills another.
        #expect(half.withUnsafeBufferPointer { analyzer.add($0, sampleRate: sampleRate, into: &levels) })
    }
}

@Suite("Equalizer smoothing")
struct AudioLevelsSmoothingTests {
    @Test func barsRiseQuicklyAndFallSlowly() {
        let smoothed = AudioLevels.smooth([0.5, 0.5], toward: [1, 0])

        #expect(abs(smoothed[0] - (0.5 + 0.5 * AudioLevels.attack)) < 0.0001)
        #expect(abs(smoothed[1] - (0.5 - 0.5 * AudioLevels.release)) < 0.0001)
        #expect(AudioLevels.attack > AudioLevels.release)
    }

    @Test func firstLevelsShowAsTheyAre() {
        #expect(AudioLevels.smooth(nil, toward: [0.2, 0.8]) == [0.2, 0.8])
    }
}

@Suite("Apps that send sound")
struct AudibleAppsTests {
    @Test func helpersCountAsTheirApp() {
        #expect(AudibleApps.matches("com.google.Chrome.helper", ["com.google.Chrome"]))
        #expect(AudibleApps.matches("org.mozilla.firefox", ["org.mozilla.firefox"]))
        #expect(!AudibleApps.matches("com.google.Chromecast", ["com.google.Chrome"]))
        #expect(!AudibleApps.matches("org.mozilla.firefox", []))
    }

    @Test func cantTellWithoutAnApp() {
        #expect(AudibleApps.isAudible([]) == nil)
    }
}
