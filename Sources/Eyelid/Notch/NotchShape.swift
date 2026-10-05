import SwiftUI

/// A notch outline: concave "ears" at the top corners that blend into the screen edge,
/// and rounded corners at the bottom.
///
/// The ears stick out by `topCornerRadius` on each side, so the body of the notch is
/// `rect.width - 2 * topCornerRadius` wide.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat
    /// How far the lower lid hangs below the corners: the bottom edge then runs from them down to the middle in an
    /// almond curve, like the lower lid of an eye.
    var lowerLidDepth: CGFloat = 0

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(topCornerRadius, bottomCornerRadius), lowerLidDepth) }
        set {
            topCornerRadius = newValue.first.first
            bottomCornerRadius = newValue.first.second
            lowerLidDepth = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let top = topCornerRadius
        let lid = min(max(lowerLidDepth, 0), rect.height - top)
        let bottom = min(bottomCornerRadius, (rect.width - 2 * top) / 2, rect.height - top - lid)
        // Where the bottom corners are, above the lid.
        let cornerY = rect.maxY - lid
        let left = rect.minX + top
        let right = rect.maxX - top

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Top-left ear.
        path.addQuadCurve(to: CGPoint(x: left, y: rect.minY + top), control: CGPoint(x: left, y: rect.minY))
        path.addLine(to: CGPoint(x: left, y: cornerY - bottom))

        // Bottom-left corner.
        path.addQuadCurve(to: CGPoint(x: left + bottom, y: cornerY), control: CGPoint(x: left, y: cornerY))

        // The bottom edge: straight without a lid, otherwise an almond curve down to the middle and back up.
        let (_, control1, control2, middle) = Almond.leftHalf(from: left + bottom, to: rect.midX, top: cornerY, depth: lid)
        path.addCurve(to: middle, control1: control1, control2: control2)
        path.addCurve(
            to: CGPoint(x: right - bottom, y: cornerY),
            control1: CGPoint(x: rect.maxX - control2.x + rect.minX, y: control2.y),
            control2: CGPoint(x: rect.maxX - control1.x + rect.minX, y: control1.y)
        )

        // Bottom-right corner.
        path.addQuadCurve(to: CGPoint(x: right, y: cornerY - bottom), control: CGPoint(x: right, y: cornerY))
        path.addLine(to: CGPoint(x: right, y: rect.minY + top))

        // Top-right ear.
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: right, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
