import AppKit
import os

private let logger = Logger(subsystem: "io.github.satis-ku.eyelid", category: "Shelf")

/// Files dropped on the notch: file URLs from Finder and most apps, and files that apps such as Photos, Mail and
/// Safari write only once they are dropped.
@MainActor
enum ShelfDrop {
    static let pasteboardTypes: [NSPasteboard.PasteboardType] =
        [NSPasteboard.PasteboardType.fileURL] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }

    /// Promised files are written here before they reach the shelf.
    private static let promiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()

    /// Whether a drag carries files, judging by the types on its pasteboard. Text, links and the like don't count.
    static func carriesFiles(_ types: [NSPasteboard.PasteboardType]?) -> Bool {
        guard let types else { return false }
        return !Set(types).isDisjoint(with: pasteboardTypes)
    }

    /// Adds the files on a drop pasteboard to the shelf. Promised files follow once their app has written them.
    /// Returns whether there was anything to add.
    static func receive(_ pasteboard: NSPasteboard, into shelf: Shelf) -> Bool {
        let objects = pasteboard.readObjects(
            forClasses: [NSFilePromiseReceiver.self, NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) ?? []

        let urls = objects.compactMap { $0 as? URL }
        shelf.add(urls)

        let promises = objects.compactMap { $0 as? NSFilePromiseReceiver }
        if !promises.isEmpty {
            receive(promises, into: shelf)
        }
        return !urls.isEmpty || !promises.isEmpty
    }

    private static func receive(_ promises: [NSFilePromiseReceiver], into shelf: Shelf) {
        let folder: URL
        do {
            folder = try shelf.makePromisedFilesFolder()
        } catch {
            logger.error("No folder for promised files: \(error.localizedDescription, privacy: .public)")
            return
        }

        for promise in promises {
            promise.receivePromisedFiles(
                atDestination: folder,
                options: [:],
                operationQueue: promiseQueue,
                reader: promisedFileHandler(for: shelf)
            )
        }
    }

    /// Called by AppKit on `promiseQueue` as each promised file is written, so it must not belong to the main actor:
    /// Swift checks that at run time, and a main-actor closure called there crashes. Apps such as VS Code hand over
    /// every file this way.
    nonisolated static func promisedFileHandler(for shelf: Shelf) -> @Sendable (URL, (any Error)?) -> Void {
        { url, error in
            if let error {
                logger.error("A promised file never came: \(error.localizedDescription, privacy: .public)")
                return
            }
            Task { @MainActor in
                shelf.add([url])
            }
        }
    }
}
