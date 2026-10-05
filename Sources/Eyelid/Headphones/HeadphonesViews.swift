import SwiftUI

/// Headphones that just connected, on both sides of the closed notch: their icon, and their charge once known.
struct HeadphonesActivityView: View {
    let event: HeadphonesEvent
    let notchSize: CGSize

    var body: some View {
        let sideWidth = NotchViewModel.Layout.hudSideWidth

        HStack(spacing: 0) {
            Image(systemName: event.icon.availableSymbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: sideWidth)
            Spacer()
                .frame(width: notchSize.width)
            Group {
                if let level = event.battery?.level {
                    HeadphonesBatteryLevel(level: level)
                        .transition(.opacity)
                }
            }
            .frame(width: sideWidth)
        }
        .frame(height: notchSize.height)
        .animation(.easeOut(duration: 0.2), value: event.battery)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let level = event.battery?.level else { return "\(event.name) connected" }
        return "\(event.name) connected, \(level)%"
    }
}

/// A ring and a percentage, as iOS shows AirPods.
private struct HeadphonesBatteryLevel: View {
    let level: Int

    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: CGFloat(level) / 100)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 13, height: 13)

            Text("\(level)%")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
        }
    }

    private var tint: Color {
        level <= 20 ? .red : .green
    }
}
