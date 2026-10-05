import SwiftUI

/// A notch outline: concave "ears" at the top corners that blend into the screen edge,
/// and rounded corners at the bottom.
///
/// The ears stick out by `topCornerRadius` on each side, so the body of the notch is
/// `rect.width - 2 * topCornerRadius` wide.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat
    /// Curves the bottom edge like a lower eyelid: its middle stays at the bottom, and the corners rise by this much.
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
        let lid = min(max(lowerLidDepth, 0), rect.height / 4)
        let bottom = min(bottomCornerRadius, (rect.width - 2 * top) / 2, rect.height - top - lid)
        // Where the bottom corners end, raised for the lower eyelid.
        let cornerY = rect.maxY - lid

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Top-left ear.
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + top, y: rect.minY + top),
            control: CGPoint(x: rect.minX + top, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + top, y: cornerY - bottom))

        // Bottom-left corner.
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + top + bottom, y: cornerY),
            control: CGPoint(x: rect.minX + top, y: cornerY)
        )
        // The bottom edge: straight, or hanging down to the bottom in the middle. A quadratic curve reaches halfway to
        // its control point, so the control point sits twice as far below the corners.
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - top - bottom, y: cornerY),
            control: CGPoint(x: rect.midX, y: cornerY + 2 * lid)
        )

        // Bottom-right corner.
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - top, y: cornerY - bottom),
            control: CGPoint(x: rect.maxX - top, y: cornerY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))

        // Top-right ear.
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - top, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}
