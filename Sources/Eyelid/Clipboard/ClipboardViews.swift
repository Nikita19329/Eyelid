import SwiftUI

/// The clipboard history in the open notch: a compact list, newest first.
struct ClipboardView: View {
    let model: NotchViewModel

    var body: some View {
        let entries = model.clipboard.entries

        VStack(spacing: 6) {
            if entries.isEmpty {
                ClipboardPlaceholder(access: model.clipboard.access)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                Button {
                                    model.choose(entry)
                                } label: {
                                    ClipboardRow(entry: entry, isSelected: index == model.clipboardSelection)
                                }
                                .buttonStyle(.plain)
                                .id(entry.id)
                            }
                        }
                    }
                    .scrollIndicators(.never)
                    .onChange(of: model.clipboardSelection) { _, selection in
                        guard entries.indices.contains(selection) else { return }
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(entries[selection].id)
                        }
                    }
                }
            }

            if model.isHeldOpen {
                Text("↑↓ to choose  ·  ↩ to copy  ·  ⌫ to remove  ·  ⎋ to close")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 4)
    }
}

private struct ClipboardRow: View {
    let entry: ClipboardEntry
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ClipboardIcon(entry: entry)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.9))
                    // Long copies stay compact. The selected one shows a little more of itself.
                    .lineLimit(isSelected ? 4 : 2)
                    .truncationMode(entry.kind == .files ? .middle : .tail)
                    .multilineTextAlignment(.leading)
                if let detail = entry.detail {
                    Text(detail)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(isSelected ? 0.12 : 0))
        )
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

/// An image's thumbnail, a file's icon, or the icon of the app the text came from.
private struct ClipboardIcon: View {
    let entry: ClipboardEntry

    var body: some View {
        Group {
            if let thumbnail = entry.thumbnail {
                Image(decorative: thumbnail, scale: 2)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else if let file = entry.fileURLs.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: file.path(percentEncoded: false)))
                    .resizable()
            } else if let app = entry.sourceAppURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path(percentEncoded: false)))
                    .resizable()
            } else {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(width: 24, height: 24)
    }
}

private struct ClipboardPlaceholder: View {
    let access: ClipboardHistory.Access

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 20, weight: .medium))
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white.opacity(0.5))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private var message: String {
        switch access {
        case .allowed:
            "What you copy shows up here."
        case .ask, .denied, .notAskedYet:
            "Allow Eyelid in System Settings → Privacy & Security → Paste from Other Apps to keep what you copy."
        }
    }
}
