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
            // in the closed notch, otherwise the tabs on the left and the battery on the right.
            ZStack {
                if let hud = model.hud {
                    HUDView(event: hud, style: model.settings.hudLevelStyle, notchSize: model.geometry.notchSize)
                        .transition(.opacity)
                } else {
                    HStack {
                        if model.settings.shelfEnabled || model.settings.clipboardEnabled {
                            NotchTabs(model: model)
                        }
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
                if model.showsShelf {
                    ShelfView(model: model)
                } else if model.showsClipboard {
                    ClipboardView(model: model)
                } else if let track = model.nowPlaying.track {
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

/// Switches the open notch between now playing, the shelf and the clipboard history.
private struct NotchTabs: View {
    let model: NotchViewModel

    var body: some View {
        HStack(spacing: 2) {
            TabButton(title: "Now Playing", systemImage: "music.note", isSelected: model.tab == .nowPlaying) {
                model.tab = .nowPlaying
            }
            if model.settings.shelfEnabled {
                TabButton(
                    title: "Shelf",
                    systemImage: model.shelf.items.isEmpty ? "tray" : "tray.full",
                    isSelected: model.tab == .shelf
                ) {
                    model.tab = .shelf
                }
            }
            if model.settings.clipboardEnabled {
                TabButton(title: "Clipboard", systemImage: "doc.on.clipboard", isSelected: model.tab == .clipboard) {
                    model.clipboardSelection = 0
                    model.tab = .clipboard
                }
            }
        }
    }
}

private struct TabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(isSelected ? 1 : 0.45))
                .frame(width: 28, height: 22)
                .background(Capsule().fill(.white.opacity(isSelected ? 0.14 : 0)))
                .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}
