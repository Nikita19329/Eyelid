import AppKit

@MainActor
protocol NotchDropDelegate: AnyObject {
    /// What a drop would do at the drag's location, or no operation where the notch doesn't take it.
    func dropOperation(for drag: any NSDraggingInfo) -> NSDragOperation
    func dragDidExit()
    func performDrop(_ drag: any NSDraggingInfo) -> Bool
}

/// The panel's content view: holds the SwiftUI content and takes the files dragged onto any part of it.
final class NotchDropView: NSView {
    weak var delegate: (any NotchDropDelegate)?

    init(content: NSView) {
        super.init(frame: .zero)
        content.autoresizingMask = [.width, .height]
        addSubview(content)
        registerForDraggedTypes(ShelfDrop.pasteboardTypes)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        delegate?.dropOperation(for: sender) ?? []
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        delegate?.dropOperation(for: sender) ?? []
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        delegate?.dragDidExit()
    }

    override func draggingEnded(_ sender: any NSDraggingInfo) {
        delegate?.dragDidExit()
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        delegate?.performDrop(sender) ?? false
    }
}
