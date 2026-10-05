import CoreGraphics
import Foundation
import ImageIO

/// Now playing artwork, decoded away from the main thread and scaled down.
///
/// Any app or web page can set the artwork, and Eyelid decodes it in a process that may hold Accessibility
/// access. So it only decodes images of a sensible size, and only as large as the notch shows them.
struct Artwork: @unchecked Sendable {
    /// Base64 longer than this, about 8 MB of image data, is dropped without decoding.
    static let maxEncodedLength = 11_000_000
    /// Images that claim more pixels than this are dropped before their pixels are decoded.
    static let maxSourcePixels = 50_000_000
    /// The notch shows artwork at 72 pt at most, so this covers Retina screens with room to spare.
    static let maxPixelSize = 288

    /// Immutable, so safe to share between threads.
    let image: CGImage

    init?(data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              Self.isAcceptable(width: width, height: height)
        else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        self.image = image
    }

    static func isAcceptable(width: Int, height: Int) -> Bool {
        let (pixels, overflow) = width.multipliedReportingOverflow(by: height)
        return width > 0 && height > 0 && !overflow && pixels <= maxSourcePixels
    }
}
