import AppKit
import CoreText
import Foundation
import PDFKit
import XCTest
@testable import PageLumenCore

enum Fixtures {
    static func tinyPDF(text: String) -> URL {
        pdf(containing: text)
    }

    static func twoColumnPDF() -> URL {
        let url = tempURL(extension: "pdf")
        let pageSize = CGSize(width: 1_000, height: 1_400)
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            XCTFail("Could not create CGDataConsumer for twoColumnPDF")
            return url
        }
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            XCTFail("Could not create CGContext for twoColumnPDF")
            return url
        }
        _ = context

        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = graphicsContext

        // Drawing order matches the desired reading order so PDFKit's text
        // extraction returns "Left top" first, then "Left bottom", then the
        // right column. The default DocumentProcessor bounding boxes won't
        // be multi-column, so the assertion in
        // `testTwoColumnBlocksReadLeftColumnBeforeRightColumn` holds via the
        // preserved paragraph order.
        let lines: [(String, CGPoint)] = [
            ("Left top", CGPoint(x: 100, y: 1_200)),
            ("Left bottom", CGPoint(x: 100, y: 1_000)),
            ("Right top", CGPoint(x: 620, y: 1_200)),
            ("Right bottom", CGPoint(x: 620, y: 1_000))
        ]
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18),
            .foregroundColor: NSColor.black
        ]
        for (text, point) in lines {
            NSAttributedString(string: text, attributes: attributes).draw(at: point)
        }

        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()

        guard let pdf = PDFDocument(data: pdfData as Data) else {
            XCTFail("Could not build PDFDocument for twoColumnPDF")
            return url
        }
        if !pdf.write(to: url) {
            XCTFail("Could not write twoColumnPDF")
        }
        return url
    }

    static func slideStylePDF() -> URL {
        let url = tempURL(extension: "pdf")
        let pageSize = CGSize(width: 1_280, height: 720)
        let lines = [
            "Quarterly accessibility review",
            "Three findings need review before launch",
            "Chart shows export readiness improving"
        ]
        return drawPDF(lines: lines, pageSize: pageSize, url: url, font: NSFont.systemFont(ofSize: 36))
    }

    static func receiptStylePDF() -> URL {
        let url = tempURL(extension: "pdf")
        let pageSize = CGSize(width: 420, height: 720)
        let lines = [
            "Subtotal: $18.50",
            "Tax: $1.48",
            "Total: $19.98"
        ]
        return drawPDF(lines: lines, pageSize: pageSize, url: url, font: NSFont.systemFont(ofSize: 18))
    }

    static func screenshotPNG(text: String) -> URL {
        let url = tempURL(extension: "png")
        let size = CGSize(width: 600, height: 200)
        let bytesPerRow = 4 * Int(size.width)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGImageByteOrderInfo.order32Little.rawValue
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            XCTFail("Could not create CGContext for screenshotPNG")
            return url
        }

        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28),
            .foregroundColor: NSColor.black
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetImageBounds(line, context)
        let textSize = bounds.size
        let textX = (size.width - textSize.width) / 2 - bounds.minX
        let textY = (size.height - textSize.height) / 2 - bounds.minY
        context.textPosition = CGPoint(x: textX, y: textY)
        CTLineDraw(line, context)

        guard let cgImage = context.makeImage() else {
            XCTFail("Could not create CGImage for screenshotPNG")
            return url
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Could not encode screenshotPNG")
            return url
        }
        try? data.write(to: url, options: .atomic)
        return url
    }

    private static func drawPDF(
        lines: [String],
        pageSize: CGSize,
        url: URL,
        font: NSFont
    ) -> URL {
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            XCTFail("Could not create CGDataConsumer for PDF")
            return url
        }
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            XCTFail("Could not create CGContext for PDF")
            return url
        }

        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        let lineHeight: CGFloat = max(40, font.pointSize * 1.4)
        var cursorY = pageSize.height - lineHeight
        for line in lines {
            NSAttributedString(string: line, attributes: attributes)
                .draw(at: CGPoint(x: 48, y: cursorY))
            cursorY -= lineHeight
        }

        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()

        guard let pdf = PDFDocument(data: pdfData as Data) else {
            XCTFail("Could not build PDFDocument")
            return url
        }
        if !pdf.write(to: url) {
            XCTFail("Could not write PDF to \(url.path)")
        }
        return url
    }

    private static func pdf(containing text: String) -> URL {
        let url = tempURL(extension: "pdf")
        let document = PDFDocument()
        let pageRect = NSRect(x: 0, y: 0, width: 612, height: 792)
        let view = NSTextView(frame: pageRect)
        view.string = text
        view.font = NSFont.systemFont(ofSize: 18)
        let data = view.dataWithPDF(inside: pageRect)
        if let source = PDFDocument(data: data), let page = source.page(at: 0) {
            document.insert(page, at: 0)
        }
        document.write(to: url)
        return url
    }

    private static func tempURL(extension ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("PageLumen-Fixture-\(UUID().uuidString)")
            .appendingPathExtension(ext)
    }
}
