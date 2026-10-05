import SwiftUI

/// The shelf in the open notch: a row of files, or a place to drop them.
struct ShelfView: View {
    let model: NotchViewModel

    var body: some View {
        let shelf = model.shelf

        if shelf.items.isEmpty {
            DropPrompt(isTargeted: model.isDropTargeted)
        } else {
            HStack(spacing: 6) {
                ScrollView(.horizontal) {
                    HStack(spacing: 2) {
                        ForEach(shelf.items) { item in
                            ShelfTile(item: item, shelf: shelf, dragSource: model.shelfDragSource)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .scrollIndicators(.never)

                Button {
                    shelf.removeAll()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.white.opacity(0.12)))
                        .contentShape(Circle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Clear Shelf")
                .help("Clear Shelf")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if model.isDropTargeted {
                    DropOutline(isTargeted: true)
                }
            }
        }
    }
}

private struct ShelfTile: View {
    let item: ShelfItem
    let shelf: Shelf
    let dragSource: ShelfDragSource
    @State private var thumbnail: NSImage?

    private static let imageSide: CGFloat = 48
    private static let width: CGFloat = 70
    private static let padding: CGFloat = 4

    var body: some View {
        let image = thumbnail ?? ShelfThumbnails.image(for: item.url)

        VStack(spacing: 4) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Self.imageSide, height: Self.imageSide)
            Text(item.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(Self.padding)
        .frame(width: Self.width)
        .overlay {
            ShelfTileMouseArea(
                item: item,
                image: image,
                imageFrame: CGRect(
                    x: (Self.width - Self.imageSide) / 2,
                    y: Self.padding,
                    width: Self.imageSide,
                    height: Self.imageSide
                ),
                shelf: shelf,
                dragSource: dragSource
            )
        }
        .task(id: item.url) {
            thumbnail = await ShelfThumbnails.load(for: item.url, side: Self.imageSide)
        }
    }
}

/// Shown while the shelf is empty, and lights up while files are dragged over the notch.
private struct DropPrompt: View {
    let isTargeted: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 20, weight: .medium))
            Text(isTargeted ? "Drop to add to the shelf" : "Drop files here to keep them at hand")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.white.opacity(isTargeted ? 0.9 : 0.5))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DropOutline(isTargeted: isTargeted))
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }
}

private struct DropOutline: View {
    let isTargeted: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.white.opacity(isTargeted ? 0.08 : 0))
            .strokeBorder(
                .white.opacity(isTargeted ? 0.6 : 0.2),
                style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
            )
    }
}
