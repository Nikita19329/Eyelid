import CoreGraphics
import SwiftUI

/// The most vivid color of the artwork, used to tint the track title under the notch.
struct ArtworkColor: Equatable, Sendable {
    var red: Double
    var green: Double
    var blue: Double

    /// The artwork is scaled down to this many pixels a side before its colors are counted.
    static let sampleSide = 16
    /// Pixels grayer or darker than this don't count towards a color.
    static let minSaturation = 0.2
    static let minBrightness = 0.15
    /// How much vivid color a hue needs, in fully saturated, fully bright pixels, so that a few stray pixels in gray
    /// artwork don't decide it.
    static let minWeight = 4.0
    /// Text in this color stays readable on black: at least 8:1 contrast.
    static let minLuminance = 0.35

    /// Picks the hue that covers the most of the artwork, weighted by how vivid each pixel is, and averages its pixels.
    /// Nil for artwork without a clear color, such as black and white photos.
    static func accent(of image: CGImage) -> ArtworkColor? {
        let side = sampleSide
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                      data: buffer.baseAddress,
                      width: side,
                      height: side,
                      bitsPerComponent: 8,
                      bytesPerRow: side * 4,
                      space: space,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  )
            else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }

        let hueCount = 12
        var weights = [Double](repeating: 0, count: hueCount)
        var sums = [(red: Double, green: Double, blue: Double)](repeating: (0, 0, 0), count: hueCount)
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[offset + 3]) / 255
            guard alpha > 0.5 else { continue }
            let color = ArtworkColor(
                red: Double(pixels[offset]) / 255 / alpha,
                green: Double(pixels[offset + 1]) / 255 / alpha,
                blue: Double(pixels[offset + 2]) / 255 / alpha
            )
            let hsb = color.hsb
            guard hsb.saturation >= minSaturation, hsb.brightness >= minBrightness else { continue }

            let weight = hsb.saturation * hsb.brightness
            let hue = min(Int(hsb.hue * Double(hueCount)), hueCount - 1)
            weights[hue] += weight
            sums[hue].red += color.red * weight
            sums[hue].green += color.green * weight
            sums[hue].blue += color.blue * weight
        }

        guard let best = weights.indices.max(by: { weights[$0] < weights[$1] }), weights[best] >= minWeight else {
            return nil
        }
        let sum = sums[best]
        let weight = weights[best]
        return ArtworkColor(red: sum.red / weight, green: sum.green / weight, blue: sum.blue / weight)
    }

    /// The same hue, bright enough to read on the black notch: full brightness, and less saturated until it's light
    /// enough, which dark blues and purples need.
    var legibleOnBlack: ArtworkColor {
        var hsb = hsb
        hsb.brightness = 1
        hsb.saturation = min(hsb.saturation, 0.75)
        var color = ArtworkColor(hsb: hsb)
        while color.luminance < Self.minLuminance, hsb.saturation > 0 {
            hsb.saturation = max(hsb.saturation - 0.05, 0)
            color = ArtworkColor(hsb: hsb)
        }
        return color
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue)
    }

    // MARK: - Color math

    /// Relative luminance, as WCAG defines it.
    var luminance: Double {
        func linear(_ value: Double) -> Double {
            value <= 0.040_45 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    struct HSB {
        /// From 0 up to 1, where red is 0.
        var hue: Double
        var saturation: Double
        var brightness: Double
    }

    var hsb: HSB {
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let delta = maximum - minimum
        var hue = 0.0
        if delta > 0 {
            if maximum == red {
                hue = (green - blue) / delta
            } else if maximum == green {
                hue = (blue - red) / delta + 2
            } else {
                hue = (red - green) / delta + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return HSB(hue: hue, saturation: maximum > 0 ? delta / maximum : 0, brightness: maximum)
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    init(hsb: HSB) {
        let sector = hsb.hue * 6
        let chroma = hsb.brightness * hsb.saturation
        let x = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let (red, green, blue): (Double, Double, Double) = switch Int(sector) % 6 {
        case 0: (chroma, x, 0)
        case 1: (x, chroma, 0)
        case 2: (0, chroma, x)
        case 3: (0, x, chroma)
        case 4: (x, 0, chroma)
        default: (chroma, 0, x)
        }
        let lift = hsb.brightness - chroma
        self.init(red: red + lift, green: green + lift, blue: blue + lift)
    }
}
