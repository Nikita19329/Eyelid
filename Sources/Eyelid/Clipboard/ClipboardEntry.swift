import AppKit
import ImageIO

/// One copy: what the pasteboard held, and how the clipboard list shows it.
struct ClipboardEntry: Identifiable {
    enum Kind: Equatable {
        case text
        case files
        case image
    }

    let id = UUID()
    /// The pasteboard items, with the types Eyelid keeps, to put them back as they were.
    let items: [[NSPasteboard.PasteboardType: Data]]
    let kind: Kind
    /// One or two lines in the list: the text with its whitespace collapsed, file names, or "Image".
    let title: String
    /// Under the title, for long text, several files and images: "48 lines", "3 files", "1920 × 1080".
    let detail: String?
    let fileURLs: [URL]
    let thumbnail: CGImage?
    /// The app that was in front when the copy was made.
    var sourceAppURL: URL?
    var date: Date

    func hasSameContent(as other: ClipboardEntry) -> Bool {
        items == other.items
    }
}

extension ClipboardEntry {
    /// Builds an entry from pasteboard items. Returns nil when there's nothing the list could show.
    init?(items: [[NSPasteboard.PasteboardType: Data]], sourceAppURL: URL? = nil, date: Date = .now) {
        let fileURLs = items.compactMap { $0[.fileURL].flatMap { URL(dataRepresentation: $0, relativeTo: nil) } }
        let text = items.first?[.string].flatMap { String(data: $0, encoding: .utf8) }

        // Finder puts file names on the pasteboard as text too, so files come first.
        if !fileURLs.isEmpty {
            kind = .files
            title = fileURLs.map { FileManager.default.displayName(atPath: $0.path(percentEncoded: false)) }
                .joined(separator: ", ")
            detail = fileURLs.count > 1 ? "\(fileURLs.count) files" : nil
            thumbnail = nil
        } else if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            kind = .text
            title = Self.preview(of: text)
            detail = Self.detail(of: text)
            thumbnail = nil
        } else if let image = items.first.flatMap({ $0[.png] ?? $0[.tiff] }),
                  let source = CGImageSourceCreateWithData(image as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int {
            kind = .image
            title = "Image"
            detail = "\(width) × \(height)"
            thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 96,
            ] as CFDictionary)
        } else {
            return nil
        }

        self.items = items
        self.fileURLs = fileURLs
        self.sourceAppURL = sourceAppURL
        self.date = date
    }

    /// How much of a text the list looks at. Two lines never need more, even for a book.
    static let previewLength = 300

    /// The start of the text on a single line: line breaks and runs of spaces become one space.
    static func preview(of text: String) -> String {
        text.prefix(previewLength * 4)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .prefix(previewLength)
            .description
    }

    /// Tells how long a text is when two lines can't show all of it.
    static func detail(of text: String) -> String? {
        // Blank lines between paragraphs don't count, since the list doesn't show them.
        let lines = text.split(whereSeparator: \.isNewline).count { !$0.allSatisfy(\.isWhitespace) }
        if lines > 2 {
            return "\(lines.formatted()) lines"
        }
        let characters = text.trimmingCharacters(in: .whitespacesAndNewlines).count
        return characters > 120 ? "\(characters.formatted()) characters" : nil
    }
}
