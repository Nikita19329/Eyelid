import SwiftUI

struct NotchView: View {
    let model: NotchViewModel

    private let animation = Animation.spring(response: 0.42, dampingFraction: 0.82)

    var body: some View {
        let size = model.bodySize

        content
            .frame(width: size.width, height: size.height, alignment: .top)
            .padding(.horizontal, model.topRadius)
            .background(.black)
            .clipShape(NotchShape(topCornerRadius: model.topRadius, bottomCornerRadius: model.bottomRadius))
            .shadow(color: .black.opacity(model.state == .open ? 0.45 : 0), radius: 14, y: 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(animation, value: model.state)
            .animation(animation, value: model.showsActivity)
            .animation(animation, value: model.batteryEvent)
            .animation(animation, value: model.hud == nil)
            .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .open:
            OpenNotchView(model: model)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
        case .closed:
            if let hud = model.hud {
                HUDView(event: hud, style: model.settings.hudLevelStyle, notchSize: model.geometry.notchSize)
                    .transition(.opacity)
            } else if let event = model.batteryEvent {
                BatteryActivityView(event: event, notchSize: model.geometry.notchSize)
                    .transition(.opacity)
            } else if model.showsNowPlayingActivity, let track = model.nowPlaying.track {
                ClosedActivityView(track: track, notchSize: model.geometry.notchSize)
                    .transition(.opacity)
            }
        }
    }
}

private struct OpenNotchView: View {
    let model: NotchViewModel

    var body: some View {
        VStack(spacing: 0) {
            // The strip beside the hardware notch: the volume and brightness HUD in the same places as
            // in the closed notch, otherwise the battery on the right.
            ZStack {
                if let hud = model.hud {
                    HUDView(event: hud, style: model.settings.hudLevelStyle, notchSize: model.geometry.notchSize)
                        .transition(.opacity)
                } else {
                    HStack {
                        Spacer()
                        if let battery = model.battery.state {
                            BatteryIndicator(state: battery)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .frame(height: model.geometry.notchSize.height)
            .animation(.easeOut(duration: 0.15), value: model.hud == nil)

            Group {
                if let track = model.nowPlaying.track {
                    NowPlayingCard(track: track, nowPlaying: model.nowPlaying)
                } else {
                    Label("Nothing is playing", systemImage: "music.note")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }
}
