import SwiftUI

/// Battery level and icon in the strip next to the hardware notch, while the notch is open.
struct BatteryIndicator: View {
    let state: BatteryState

    var body: some View {
        HStack(spacing: 5) {
            Text("\(state.level)%")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
            BatteryIcon(level: state.level, isPluggedIn: state.isPluggedIn, tint: state.tint)
        }
    }
}

/// The battery on both sides of the hardware notch for a few seconds after a `BatteryEvent`.
struct BatteryActivityView: View {
    let event: BatteryEvent
    let notchSize: CGSize

    var body: some View {
        let state = event.state
        let sideWidth = NotchViewModel.Layout.activitySideWidth

        HStack(spacing: 0) {
            BatteryIcon(level: state.level, isPluggedIn: state.isPluggedIn, tint: state.tint)
                .frame(width: sideWidth)
            Spacer()
                .frame(width: notchSize.width)
            Text("\(state.level)%")
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(state.tint)
                .frame(width: sideWidth)
        }
        .frame(height: notchSize.height)
    }
}

/// A battery outline filled to the charge level, with a bolt while connected to power.
struct BatteryIcon: View {
    let level: Int
    let isPluggedIn: Bool
    let tint: Color

    var body: some View {
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .strokeBorder(.white.opacity(0.4), lineWidth: 1)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(tint)
                    .frame(width: max(1.5, 19 * CGFloat(min(max(level, 0), 100)) / 100))
                    .padding(2)
            }
            .frame(width: 23, height: 12)
            .overlay {
                if isPluggedIn {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 1)
                }
            }

            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.4))
                .frame(width: 1.5, height: 4)
        }
    }
}

extension BatteryState {
    /// Green on power, orange at 20% or less, red at 10% or less.
    var tint: Color {
        if isPluggedIn { return .green }
        if level <= 10 { return .red }
        if level <= 20 { return .orange }
        return .white
    }
}
