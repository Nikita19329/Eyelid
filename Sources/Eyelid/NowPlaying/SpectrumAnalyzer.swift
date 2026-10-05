import Accelerate

/// Splits sound into a few frequency bands and measures how loud each is, for the equalizer next to the notch.
///
/// Fed from Core Audio's real-time thread, so it allocates everything up front and never locks.
final class SpectrumAnalyzer {
    /// Bass, low mids, high mids and treble, one per bar of the equalizer.
    static let bands: [ClosedRange<Double>] = [40...200, 200...800, 800...3_000, 3_000...12_000]
    /// About 21 ms at 48 kHz: short enough to follow a beat, long enough to tell bass apart.
    static let windowSize = 1024
    /// Levels are reported from this loudness, in decibels below full scale, up to full scale.
    static let floor: Float = -60

    private let log2Size = vDSP_Length(10)
    private let setup: FFTSetup
    private let window: UnsafeMutablePointer<Float>
    private let samples: UnsafeMutablePointer<Float>
    private let windowed: UnsafeMutablePointer<Float>
    private let real: UnsafeMutablePointer<Float>
    private let imaginary: UnsafeMutablePointer<Float>
    private let power: UnsafeMutablePointer<Float>
    private var filled = 0

    init() {
        let size = Self.windowSize
        setup = vDSP_create_fftsetup(log2Size, FFTRadix(kFFTRadix2))!
        window = .allocate(capacity: size)
        vDSP_hann_window(window, vDSP_Length(size), Int32(vDSP_HANN_NORM))
        samples = .allocate(capacity: size)
        samples.initialize(repeating: 0, count: size)
        windowed = .allocate(capacity: size)
        real = .allocate(capacity: size / 2)
        imaginary = .allocate(capacity: size / 2)
        power = .allocate(capacity: size / 2)
    }

    deinit {
        vDSP_destroy_fftsetup(setup)
        for pointer in [window, samples, windowed, real, imaginary, power] {
            pointer.deallocate()
        }
    }

    /// Adds mono samples. Each time a window is full, measures the bands into `levels`, from 0 for silence to 1 for
    /// full scale, and returns true. Windows overlap by half.
    func add(_ input: UnsafeBufferPointer<Float>, sampleRate: Double, into levels: inout [Float]) -> Bool {
        let size = Self.windowSize
        var measured = false
        var index = 0
        while index < input.count {
            let count = min(size - filled, input.count - index)
            (samples + filled).update(from: input.baseAddress! + index, count: count)
            filled += count
            index += count
            if filled == size {
                measure(sampleRate: sampleRate, into: &levels)
                measured = true
                // Keep the second half for the next window.
                samples.update(from: samples + size / 2, count: size / 2)
                filled = size / 2
            }
        }
        return measured
    }

    private func measure(sampleRate: Double, into levels: inout [Float]) {
        let size = Self.windowSize
        let half = size / 2
        vDSP_vmul(samples, 1, window, 1, windowed, 1, vDSP_Length(size))

        var split = DSPSplitComplex(realp: real, imagp: imaginary)
        windowed.withMemoryRebound(to: DSPComplex.self, capacity: half) { complex in
            vDSP_ctoz(complex, 2, &split, 1, vDSP_Length(half))
        }
        vDSP_fft_zrip(setup, &split, 1, log2Size, FFTDirection(FFT_FORWARD))
        vDSP_zvmags(&split, 1, power, 1, vDSP_Length(half))

        let binWidth = sampleRate / Double(size)
        for (band, range) in Self.bands.enumerated() where band < levels.count {
            let first = max(Int((range.lowerBound / binWidth).rounded(.up)), 1)
            let last = min(Int(range.upperBound / binWidth), half - 1)
            guard first <= last else {
                levels[band] = 0
                continue
            }
            var sum: Float = 0
            vDSP_sve(power + first, 1, &sum, vDSP_Length(last - first + 1))
            // A full-scale sine comes to size² in its bin: the forward transform doubles, and the normalized Hann
            // window halves, the amplitude of size / 2.
            let decibels = 10 * log10f(sum / Float(size * size) + 1e-12)
            levels[band] = min(max((decibels - Self.floor) / -Self.floor, 0), 1)
        }
    }
}
