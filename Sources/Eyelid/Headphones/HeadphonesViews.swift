import SwiftUI

/// Headphones that just connected, on both sides of the closed notch: their icon on the left and their charge on
/// the right. When only one earbud is in use, it shows on its own side, and the charge on the other.
struct HeadphonesActivityView: View {
    let event: HeadphonesEvent
    let notchSize: CGSize

    var body: some View {
        let sideWidth = NotchViewModel.Layout.hudSideWidth
        let earbud = event.battery?.singleEarbud
        let symbol = earbud.flatMap(event.icon.earbudSymbolName) ?? event.icon.availableSymbolName
        let iconIsOnTheRight = earbud == .right && symbol != event.icon.availableSymbolName

        HStack(spacing: 0) {
            Group {
                if iconIsOnTheRight { level } else { icon(symbol) }
            }
            .frame(width: sideWidth)
            Spacer()
                .frame(width: notchSize.width)
            Group {
                if iconIsOnTheRight { icon(symbol) } else { level }
            }
            .frame(width: sideWidth)
        }
        .frame(height: notchSize.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func icon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
    }

    @ViewBuilder
    private var level: some View {
        if let level = event.battery?.level {
            HeadphonesBatteryLevel(level: level)
        }
    }

    private var accessibilityLabel: String {
        let name = switch event.battery?.singleEarbud {
        case .left: "\(event.name), left earbud"
        case .right: "\(event.name), right earbud"
        case nil: event.name
        }
        guard let level = event.battery?.level else { return "\(name) connected" }
        return "\(name) connected, \(level)%"
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
