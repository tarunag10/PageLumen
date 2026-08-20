import AppKit
import CoreGraphics
import ImageIO
import QuickLookThumbnailing

/// Host-safe Quick Look thumbnail provider. It renders only the first PDF page
/// or a bounded image thumbnail; it never runs OCR, writes caches, or persists
/// document content.
final class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        let url = request.fileURL
        let extensionName = url.pathExtension.lowercased()
        let supported = Set(["pdf", "png", "jpg", "jpeg", "tif", "tiff", "heic", "heif"])
        guard supported.contains(extensionName) else {
            handler(nil, NSError(domain: "PageLumenQuickLook", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported PageLumen thumbnail type."]))
            return
        }

        let requested = request.maximumSize
        let size = CGSize(width: max(1, min(requested.width, 512)), height: max(1, min(requested.height, 512)))
        let reply = QLThumbnailReply(contextSize: size) { context in
            Self.draw(url: url, extensionName: extensionName, in: context, size: size)
        }
        handler(reply, nil)
    }

    private static func draw(url: URL, extensionName: String, in context: CGContext, size: CGSize) -> Bool {
        context.saveGState()
        defer { context.restoreGState() }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        if extensionName == "pdf", let document = CGPDFDocument(url as CFURL), let page = document.page(at: 1) {
            let box = page.getBoxRect(.mediaBox)
            let scale = min(size.width / max(box.width, 1), size.height / max(box.height, 1))
            let drawSize = CGSize(width: box.width * scale, height: box.height * scale)
            let origin = CGPoint(x: (size.width - drawSize.width) / 2, y: (size.height - drawSize.height) / 2)
            context.translateBy(x: origin.x, y: origin.y + drawSize.height)
            context.scaleBy(x: scale, y: -scale)
            context.drawPDFPage(page)
            return true
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 512,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else {
            return false
        }
        let imageSize = CGSize(width: image.width, height: image.height)
        let scale = min(size.width / max(imageSize.width, 1), size.height / max(imageSize.height, 1))
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let rect = CGRect(x: (size.width - drawSize.width) / 2, y: (size.height - drawSize.height) / 2, width: drawSize.width, height: drawSize.height)
        context.draw(image, in: rect)
        return true
    }
}
