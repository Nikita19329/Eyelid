import SwiftUI

/// The volume or brightness on both sides of the hardware notch: an icon on the left, a level bar on the right.
struct HUDView: View {
    let event: HUDEvent
    let notchSize: CGSize

    var body: some View {
        let sideWidth = NotchViewModel.Layout.hudSideWidth

        HStack(spacing: 0) {
            Image(systemName: event.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: sideWidth)
            Spacer()
                .frame(width: notchSize.width)
            LevelBar(level: event.isMuted ? 0 : event.level)
                .frame(width: sideWidth - 22, height: 5)
                .frame(width: sideWidth)
        }
        .frame(height: notchSize.height)
    }
}

private struct LevelBar: View {
    let level: Float

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25))
                Capsule().fill(.white)
                    .frame(width: proxy.size.width * CGFloat(min(max(level, 0), 1)))
            }
        }
        .animation(.easeOut(duration: 0.15), value: level)
    }
}
