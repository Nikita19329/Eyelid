// Renders Eyelid's app icon: a close-up of a MacBook's display, where the camera in the notch is the eye and
// the lit lower edge of the notch, where Eyelid lives, is the lower eyelid.
//
// Usage: swift scripts/render-icon.swift <output.png> [size]   (default size: 1024)
//
// The layout follows Apple's macOS icon grid: on a 1024 px canvas, an 824 px continuous rounded rectangle
// with a 185.4 px corner radius, 100 px from each edge, and a soft drop shadow.

import AppKit
import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Layout of the 824 pt icon body.
enum Layout {
    static let size: CGFloat = 824
    static let cornerRadius: CGFloat = 185.4
    /// The aluminium edge of the lid.
    static let rim: CGFloat = 12
    /// Black glass between the aluminium and the screen.
    static let bezel: CGFloat = 26
    static let topBezel: CGFloat = 64
    static let screen = CGRect(x: rim + bezel, y: rim + topBezel, width: size - 2 * (rim + bezel), height: size - rim * 2 - topBezel - bezel)

    static let notch = CGRect(x: 412 - 265, y: screen.minY, width: 530, height: 214)
    static let notchEar: CGFloat = 34
    /// How far the middle of the notch's lower edge sits below the ends of its straight sides.
    static let notchDepth: CGFloat = 96
    static let camera = CGPoint(x: 412, y: screen.minY + 84)
    static let cameraRadius: CGFloat = 66

    /// The notch's lower edge: one smooth curve that leaves the straight sides vertically and dips in
    /// the middle, like a lower eyelid.
    static func notchLowerEdge(in rect: CGRect) -> (start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint) {
        let left = rect.minX + notchEar
        let right = rect.maxX - notchEar
        let sides = rect.maxY - notchDepth
        // With the controls straight below the sides, the curve passes through maxY in the middle at this height.
        let control = (rect.maxY - 0.25 * sides) / 0.75
        return (CGPoint(x: left, y: sides), CGPoint(x: left, y: control), CGPoint(x: right, y: control), CGPoint(x: right, y: sides))
    }
}

/// The notch below the top bezel: concave ears where it meets the screen edge, straight sides, and a lower
/// edge shaped like a lower eyelid.
struct NotchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let ear = Layout.notchEar
        let edge = Layout.notchLowerEdge(in: rect)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: edge.start.x, y: rect.minY + ear), control: CGPoint(x: edge.start.x, y: rect.minY))
        path.addLine(to: edge.start)
        path.addCurve(to: edge.end, control1: edge.control1, control2: edge.control2)
        path.addLine(to: CGPoint(x: edge.end.x, y: rect.minY + ear))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: edge.end.x, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// Only the notch's lower edge, for the light along it.
struct NotchLowerEdge: Shape {
    func path(in rect: CGRect) -> Path {
        let edge = Layout.notchLowerEdge(in: rect)
        var path = Path()
        path.move(to: edge.start)
        path.addCurve(to: edge.end, control1: edge.control1, control2: edge.control2)
        return path
    }
}

/// A macOS-style wallpaper: soft colour fields on a deep blue.
struct Wallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x120E3A), Color(hex: 0x2A1660)], startPoint: .top, endPoint: .bottom)
            blob(0x7C4DFF, x: 0.55, y: 0.42, radius: 300, opacity: 0.85)
            blob(0xFF3D7F, x: 0.18, y: 0.86, radius: 330, opacity: 0.9)
            blob(0x2E7BFF, x: 0.9, y: 0.78, radius: 300, opacity: 0.85)
            blob(0xFF9F5A, x: 0.08, y: 0.42, radius: 190, opacity: 0.45)
        }
    }

    private func blob(_ hex: UInt32, x: CGFloat, y: CGFloat, radius: CGFloat, opacity: Double) -> some View {
        GeometryReader { proxy in
            Circle()
                .fill(RadialGradient(colors: [Color(hex: hex, opacity: opacity), Color(hex: hex, opacity: 0)], center: .center, startRadius: 0, endRadius: radius))
                .frame(width: radius * 2, height: radius * 2)
                .position(x: proxy.size.width * x, y: proxy.size.height * y)
        }
    }
}

/// The FaceTime camera: a lens in a black housing, with a violet anti-reflective tint and highlights.
struct Camera: View {
    let radius: CGFloat

    var body: some View {
        ZStack {
            // Housing, a touch lighter than the notch, so the lens reads as a separate part.
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0x1B1C22), Color(hex: 0x0B0B0E)], center: .center, startRadius: radius * 0.6, endRadius: radius))
            Circle()
                .strokeBorder(LinearGradient(colors: [Color(hex: 0x3A3B44), Color(hex: 0x0E0E12)], startPoint: .top, endPoint: .bottom), lineWidth: radius * 0.06)

            // Glass with its coating: deep blue in the middle, violet and teal towards the edge.
            Circle()
                .fill(RadialGradient(
                    colors: [Color(hex: 0x05050C), Color(hex: 0x141245), Color(hex: 0x3A2A9C), Color(hex: 0x1E6B78), Color(hex: 0x08080F)],
                    center: .init(x: 0.46, y: 0.44), startRadius: radius * 0.05, endRadius: radius * 0.62
                ))
                .frame(width: radius * 1.24, height: radius * 1.24)
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: radius * 0.03)
                .frame(width: radius * 0.86, height: radius * 0.86)
            Circle()
                .fill(Color(hex: 0x020205))
                .frame(width: radius * 0.42, height: radius * 0.42)

            // Highlights: a soft window reflection and a sharp glint.
            Ellipse()
                .fill(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: radius * 0.62, height: radius * 0.34)
                .rotationEffect(.degrees(-28))
                .offset(x: -radius * 0.2, y: -radius * 0.26)
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: radius * 0.11, height: radius * 0.11)
                .offset(x: -radius * 0.08, y: -radius * 0.1)
            Circle()
                .fill(Color(hex: 0x9C8CFF, opacity: 0.55))
                .frame(width: radius * 0.08, height: radius * 0.08)
                .offset(x: radius * 0.22, y: radius * 0.24)
        }
        .frame(width: radius * 2, height: radius * 2)
    }
}

struct Icon: View {
    var body: some View {
        let body = RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
        let screen = Layout.screen
        let notch = Layout.notch

        ZStack(alignment: .topLeading) {
            // Aluminium edge of the lid, lit from above.
            body.fill(LinearGradient(colors: [Color(hex: 0xF1F2F5), Color(hex: 0xA9ABB5), Color(hex: 0xD3D4DA), Color(hex: 0x8E909A)], startPoint: .top, endPoint: .bottom))

            // Black glass around the screen.
            RoundedRectangle(cornerRadius: Layout.cornerRadius - Layout.rim, style: .continuous)
                .fill(Color(hex: 0x050507))
                .padding(Layout.rim)

            // The screen.
            Wallpaper()
                .frame(width: screen.width, height: screen.height)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 28, bottomLeadingRadius: Layout.cornerRadius - Layout.rim - Layout.bezel,
                    bottomTrailingRadius: Layout.cornerRadius - Layout.rim - Layout.bezel, topTrailingRadius: 28,
                    style: .continuous
                ))
                .offset(x: screen.minX, y: screen.minY)

            // Eyelid, lit up under the camera: light washing over the screen along the notch's lower edge...
            NotchLowerEdge()
                .stroke(Color(hex: 0xB45CFF), style: StrokeStyle(lineWidth: 70, lineCap: .round))
                .frame(width: notch.width, height: notch.height)
                .blur(radius: 44)
                .opacity(0.55)
                .offset(x: notch.minX, y: notch.minY)
            NotchLowerEdge()
                .stroke(LinearGradient(colors: [Color(hex: 0x8C5BFF), Color(hex: 0xFF5C9A), Color(hex: 0x8C5BFF)], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 26, lineCap: .round))
                .frame(width: notch.width, height: notch.height)
                .blur(radius: 16)
                .offset(x: notch.minX, y: notch.minY)

            // ...the notch itself...
            NotchShape()
                .fill(LinearGradient(colors: [Color(hex: 0x050507), Color(hex: 0x0C0C10)], startPoint: .top, endPoint: .bottom))
                .frame(width: notch.width, height: notch.height)
                .offset(x: notch.minX, y: notch.minY)

            // ...and a thin rim of light on its edge.
            NotchLowerEdge()
                .stroke(LinearGradient(colors: [Color(hex: 0xB79CFF, opacity: 0.2), Color(hex: 0xFFC2DA, opacity: 0.95), Color(hex: 0xB79CFF, opacity: 0.2)], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .frame(width: notch.width, height: notch.height)
                .offset(x: notch.minX, y: notch.minY)

            Camera(radius: Layout.cameraRadius)
                .position(Layout.camera)

            // Glass: a soft diagonal reflection across the whole display.
            LinearGradient(colors: [.white.opacity(0.13), .white.opacity(0.03), .clear], startPoint: .topLeading, endPoint: .init(x: 0.62, y: 0.55))
                .padding(Layout.rim)
                .allowsHitTesting(false)

            // A crisp highlight where the aluminium catches the light.
            body.strokeBorder(LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0.1), .clear], startPoint: .top, endPoint: .center), lineWidth: 2)
        }
        .frame(width: Layout.size, height: Layout.size)
        .clipShape(body)
        .shadow(color: .black.opacity(0.35), radius: 14, y: 10)
        .frame(width: 1024, height: 1024)
    }
}

@MainActor
func render(to url: URL, size: CGFloat) throws {
    let renderer = ImageRenderer(content: Icon())
    renderer.scale = size / 1024
    guard let image = renderer.cgImage,
          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    else { throw CocoaError(.fileWriteUnknown) }
    try png.write(to: url)
}

let arguments = CommandLine.arguments.dropFirst()
guard let output = arguments.first else {
    print("usage: swift scripts/render-icon.swift <output.png> [size]")
    exit(1)
}
let size = arguments.dropFirst().first.flatMap(Double.init) ?? 1024
try MainActor.assumeIsolated {
    try render(to: URL(filePath: output), size: size)
}
print("wrote \(output) (\(Int(size)) px)")
