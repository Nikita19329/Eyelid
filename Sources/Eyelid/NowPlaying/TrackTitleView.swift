import SwiftUI

/// The track title under the closed notch: one line in the color of the artwork, scrolling by when it doesn't fit.
struct TrackTitleView: View {
    let title: TrackTitle
    let color: ArtworkColor?
    /// Room for the text, in points.
    let width: CGFloat

    /// Where the scrolling text fades in and out at the sides.
    private static let fadeWidth: CGFloat = 14

    private var tint: Color {
        color?.legibleOnBlack.color ?? .white
    }

    var body: some View {
        Group {
            if title.scrolls(in: width) {
                TimelineView(.animation) { context in
                    let offset = title.offset(after: context.date.timeIntervalSince(title.date), in: width)
                    // Two copies, so the next one follows the first in from the right.
                    HStack(spacing: TrackTitle.gap) {
                        label
                        label
                    }
                    .fixedSize()
                    .offset(x: -offset)
                    .frame(width: width, alignment: .leading)
                    // The left side fades only once the text moves, so its first letters show in full until then.
                    .mask(edgeFade(leading: min(offset, Self.fadeWidth)))
                }
            } else {
                label
                    .frame(width: width)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title.title, title.detail].compactMap(\.self).joined(separator: ", "))
    }

    private var label: some View {
        var text = Text(title.title)
            .font(.system(size: TrackTitle.fontSize, weight: .semibold))
            .foregroundStyle(tint)
        if let detail = title.detail {
            text = text + Text(TrackTitle.separator + detail)
                .font(.system(size: TrackTitle.fontSize, weight: .medium))
                .foregroundStyle(tint.opacity(0.7))
        }
        return text.lineLimit(1)
    }

    private func edgeFade(leading: CGFloat) -> some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: leading / width),
                .init(color: .black, location: 1 - Self.fadeWidth / width),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
