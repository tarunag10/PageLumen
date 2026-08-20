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

    /// A deterministic three-column text fixture. It is intentionally native
    /// PDF text so corpus structure tests do not pretend to measure OCR.
    static func threeColumnPDF() -> URL {
        let url = tempURL(extension: "pdf")
        return drawPositionedPDF(
            lines: [
                ("Column one", CGPoint(x: 60, y: 1_150)),
                ("Column one detail", CGPoint(x: 60, y: 1_080)),
                ("Column two", CGPoint(x: 360, y: 1_150)),
                ("Column two detail", CGPoint(x: 360, y: 1_080)),
                ("Column three", CGPoint(x: 660, y: 1_150)),
                ("Column three detail", CGPoint(x: 660, y: 1_080))
            ], pageSize: CGSize(width: 900, height: 1_300), url: url
        )
    }

    static func legalFilingPDF() -> URL {
        drawMultiPagePDF(linesByPage: [
            ["IN THE HIGH COURT", "Claimant v Defendant", "Statement of case", "1. The claimant relies on the following facts."],
            ["Schedule 1", "Paragraph", "Date", "Amount", "The parties reserve their rights."]
        ], pageSize: CGSize(width: 612, height: 792), url: tempURL(extension: "pdf"))
    }

    static func multiPageTablePDF() -> URL {
        drawMultiPagePDF(linesByPage: [
            ["Item | Quantity | Price", "Paper | 2 | $4.00", "Ink | 1 | $12.00"],
            ["Item | Quantity | Price", "Folder | 3 | $6.00", "Total | 6 | $22.00"]
        ], pageSize: CGSize(width: 612, height: 792), url: tempURL(extension: "pdf"))
    }

    static func chartPDF() -> URL {
        let url = tempURL(extension: "pdf")
        return drawPositionedPDF(
            lines: [("Revenue by quarter", CGPoint(x: 80, y: 650)), ("Q1 10", CGPoint(x: 100, y: 480)), ("Q2 18", CGPoint(x: 240, y: 540)), ("Q3 14", CGPoint(x: 380, y: 510))],
            pageSize: CGSize(width: 612, height: 792), url: url
        )
    }

    static func rotatedPagePDF() -> URL {
        // The text is native and the page transform is deterministic; this
        // exercises rotated-page classification without requiring OCR.
        return drawMultiPagePDF(linesByPage: [["Rotated page heading", "Reading order remains explicit"]], pageSize: CGSize(width: 792, height: 612), url: tempURL(extension: "pdf"), rotate: true)
    }

    static func multilingualPDF() -> URL {
        drawPDF(lines: ["English heading", "हिन्दी पाठ", "中文文本", "Texto español"], pageSize: CGSize(width: 612, height: 792), url: tempURL(extension: "pdf"), font: NSFont.systemFont(ofSize: 18))
    }

    static func lowQualityScanPNG() -> URL { screenshotPNG(text: "low quality scan", fontSize: 10, foreground: .darkGray) }
    static func handwritingPNG() -> URL { screenshotPNG(text: "handwriting proxy", fontSize: 24, foreground: .black, fontName: "Marker Felt") }
    static func equationPDF() -> URL { tinyPDF(text: "f(x) = x² + 2x + 1") }
    static func OCRTrapPDF() -> URL { tinyPDF(text: "O 0 I l 1 rn m 5 S") }

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
        screenshotPNG(text: text, fontSize: 28, foreground: .black)
    }

    private static func screenshotPNG(text: String, fontSize: CGFloat, foreground: NSColor, fontName: String? = nil) -> URL {
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
            .font: fontName.flatMap { NSFont(name: $0, size: fontSize) } ?? NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: foreground
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

    private static func drawMultiPagePDF(
        linesByPage: [[String]],
        pageSize: CGSize,
        url: URL,
        rotate: Bool = false
    ) -> URL {
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { XCTFail("Could not create PDF consumer"); return url }
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { XCTFail("Could not create PDF context"); return url }
        for lines in linesByPage {
            context.beginPDFPage(nil)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            if rotate { context.translateBy(x: pageSize.width, y: 0); context.rotate(by: .pi / 2) }
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 18), .foregroundColor: NSColor.black]
            var y = (rotate ? pageSize.width : pageSize.height) - 48
            for line in lines { NSAttributedString(string: line, attributes: attributes).draw(at: CGPoint(x: 48, y: y)); y -= 32 }
            NSGraphicsContext.restoreGraphicsState(); context.endPDFPage()
        }
        context.closePDF()
        guard let pdf = PDFDocument(data: pdfData as Data), pdf.write(to: url) else { XCTFail("Could not write multipage PDF"); return url }
        return url
    }

    private static func drawPositionedPDF(lines: [(String, CGPoint)], pageSize: CGSize, url: URL) -> URL {
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { XCTFail("Could not create PDF consumer"); return url }
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { XCTFail("Could not create PDF context"); return url }
        context.beginPDFPage(nil); NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 18), .foregroundColor: NSColor.black]
        for (line, point) in lines { NSAttributedString(string: line, attributes: attributes).draw(at: point) }
        NSGraphicsContext.restoreGraphicsState(); context.endPDFPage(); context.closePDF()
        guard let pdf = PDFDocument(data: pdfData as Data), pdf.write(to: url) else { XCTFail("Could not write positioned PDF"); return url }
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
