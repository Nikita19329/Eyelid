// Renders Eyelid's app icon: the notch, hanging from the top edge like an eyelid over an iris.
//
// Usage: swift scripts/render-icon.swift <output.png> [size]   (default size: 1024)
//
// The layout follows Apple's macOS icon grid: on a 1024 px canvas, an 824 px continuous rounded rectangle
// with a 185.4 px corner radius, 100 px from each edge, and a soft drop shadow.

import AppKit
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// The notch as an eyelid: concave ears where it meets the top edge, straight sides, and a lower edge that
/// sags `depth` points below the sides in one smooth curve, like a lid over an eyeball.
struct EyelidShape: Shape {
    let earRadius: CGFloat
    let depth: CGFloat

    func path(in rect: CGRect) -> Path {
        let ear = earRadius
        let left = rect.minX + ear
        let right = rect.maxX - ear
        let sides = rect.maxY - depth
        // A cubic whose control points sit straight below the sides leaves them vertically, with no kink,
        // and passes through the middle at maxY when the controls are at this height.
        let control = (rect.maxY - 0.25 * sides) / 0.75

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: left, y: rect.minY + ear), control: CGPoint(x: left, y: rect.minY))
        path.addLine(to: CGPoint(x: left, y: sides))
        path.addCurve(
            to: CGPoint(x: right, y: sides),
            control1: CGPoint(x: left, y: control),
            control2: CGPoint(x: right, y: control)
        )
        path.addLine(to: CGPoint(x: right, y: rect.minY + ear))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: right, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct Icon: View {
    var body: some View {
        // Everything is laid out in the 824 pt body, then placed on the 1024 pt canvas.
        let body = RoundedRectangle(cornerRadius: 185.4, style: .continuous)
        let irisCenter = CGPoint(x: 412, y: 400)

        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(hex: 0x7B6CF6), Color(hex: 0x3A2E9E)], startPoint: .top, endPoint: .bottom)

            // A glow around the eye.
            RadialGradient(colors: [Color(hex: 0xFF7FA8).opacity(0.45), .clear], center: .init(x: 0.5, y: 0.55), startRadius: 0, endRadius: 380)

            // Iris, pupil and catchlight.
            Circle()
                .fill(RadialGradient(
                    colors: [Color(hex: 0xFFE6EF), Color(hex: 0xFF6F95), Color(hex: 0xB548D9), Color(hex: 0x4A2BB8)],
                    center: .center, startRadius: 30, endRadius: 225
                ))
                .overlay(Circle().strokeBorder(Color(hex: 0x241468).opacity(0.85), lineWidth: 14))
                .frame(width: 450, height: 450)
                .position(irisCenter)
            Circle()
                .fill(Color(hex: 0x100C24))
                .frame(width: 160, height: 160)
                .position(irisCenter)
            Circle()
                .fill(.white.opacity(0.92))
                .frame(width: 58, height: 58)
                .position(x: irisCenter.x + 70, y: irisCenter.y + 48)

            // The notch, hanging from the top edge over the upper part of the eye.
            EyelidShape(earRadius: 36, depth: 150)
                .fill(.black)
                .frame(width: 600, height: 290)
                .position(x: 412, y: 145)
        }
        .frame(width: 824, height: 824)
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
