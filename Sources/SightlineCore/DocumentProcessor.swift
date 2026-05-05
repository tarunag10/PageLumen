import AppKit
import Foundation
import PDFKit
import Vision

public enum DocumentProcessorError: LocalizedError, Sendable {
    case unsupportedFile(URL)
    case unreadableImage
    case unreadablePDF(URL)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFile(let url):
            return "Sightline Reader does not support \(url.lastPathComponent)."
        case .unreadableImage:
            return "The selected image could not be decoded."
        case .unreadablePDF(let url):
            return "The PDF \(url.lastPathComponent) could not be opened."
        }
    }
}

public final class DocumentProcessor: @unchecked Sendable {
    private let analyzer: LayoutAnalyzer

    public init(analyzer: LayoutAnalyzer = LayoutAnalyzer()) {
        self.analyzer = analyzer
    }

    public func process(url: URL) async throws -> ReaderDocument {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            return try await processPDF(url: url)
        }

        if ["png", "jpg", "jpeg", "tif", "tiff", "heic"].contains(ext) {
            let image = try loadImage(from: url)
            return try await process(image: image, title: url.deletingPathExtension().lastPathComponent, sourceType: .image, sourceURL: url)
        }

        throw DocumentProcessorError.unsupportedFile(url)
    }

    public func processClipboardImage(_ image: NSImage) async throws -> ReaderDocument {
        try await process(image: image, title: "Clipboard Image", sourceType: .clipboard, sourceURL: nil)
    }

    private func processPDF(url: URL) async throws -> ReaderDocument {
        guard let pdf = PDFDocument(url: url) else {
            throw DocumentProcessorError.unreadablePDF(url)
        }

        var pages: [ReaderPage] = []
        for index in 0..<pdf.pageCount {
            guard let pdfPage = pdf.page(at: index) else { continue }
            let pageNumber = index + 1
            let bounds = pdfPage.bounds(for: .mediaBox)
            let thumbnailData = thumbnailData(for: pdfPage)
            let embeddedText = pdfPage.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let blocks: [TextBlock]
            if !embeddedText.isEmpty {
                blocks = makeBlocks(from: embeddedText, pageNumber: pageNumber, pageSize: bounds.size, source: "embedded-pdf", confidence: 0.98)
            } else if let image = render(pdfPage: pdfPage), let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                blocks = try await recognizeText(in: cgImage, pageNumber: pageNumber, pageSize: bounds.size)
            } else {
                blocks = [
                    TextBlock(
                        pageNumber: pageNumber,
                        type: .unknown,
                        text: "No readable text was found on this page.",
                        bounds: BoundingBox(x: 0, y: 0, width: bounds.width, height: 32),
                        confidence: 0.0
                    )
                ]
            }

            pages.append(
                ReaderPage(
                    pageNumber: pageNumber,
                    size: PageSize(width: bounds.width, height: bounds.height),
                    thumbnailData: thumbnailData,
                    ocrStatus: .complete,
                    blocks: blocks
                )
            )
        }

        let document = ReaderDocument(
            title: url.deletingPathExtension().lastPathComponent,
            sourceType: .pdf,
            sourceURL: url,
            processingStatus: .complete,
            pages: pages
        )
        return analyzer.analyze(document: document)
    }

    private func process(image: NSImage, title: String, sourceType: SourceType, sourceURL: URL?) async throws -> ReaderDocument {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw DocumentProcessorError.unreadableImage
        }

        let pageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let blocks = try await recognizeText(in: cgImage, pageNumber: 1, pageSize: pageSize)
        let page = ReaderPage(
            pageNumber: 1,
            size: PageSize(width: pageSize.width, height: pageSize.height),
            thumbnailData: image.pngData(maxPixelSize: 360),
            ocrStatus: .complete,
            blocks: blocks
        )

        return analyzer.analyze(
            document: ReaderDocument(
                title: title,
                sourceType: sourceType,
                sourceURL: sourceURL,
                processingStatus: .complete,
                pages: [page]
            )
        )
    }

    private func recognizeText(in cgImage: CGImage, pageNumber: Int, pageSize: CGSize) async throws -> [TextBlock] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let blocks = observations.enumerated().compactMap { index, observation -> TextBlock? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    let box = observation.boundingBox
                    let bounds = BoundingBox(
                        x: box.minX * pageSize.width,
                        y: (1 - box.maxY) * pageSize.height,
                        width: box.width * pageSize.width,
                        height: box.height * pageSize.height
                    )
                    return TextBlock(
                        pageNumber: pageNumber,
                        type: .paragraph,
                        text: candidate.string,
                        bounds: bounds,
                        confidence: Double(candidate.confidence),
                        readingOrderIndex: index,
                        metadata: ["source": "vision-ocr"]
                    )
                }
                continuation.resume(returning: blocks)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func makeBlocks(from text: String, pageNumber: Int, pageSize: CGSize, source: String, confidence: Double) -> [TextBlock] {
        let paragraphs = text
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return paragraphs.enumerated().map { index, paragraph in
            TextBlock(
                pageNumber: pageNumber,
                type: .paragraph,
                text: paragraph,
                bounds: BoundingBox(x: 48, y: 48 + Double(index * 56), width: max(100, pageSize.width - 96), height: 40),
                confidence: confidence,
                readingOrderIndex: index,
                metadata: ["source": source]
            )
        }
    }

    private func loadImage(from url: URL) throws -> NSImage {
        guard let image = NSImage(contentsOf: url) else {
            throw DocumentProcessorError.unreadableImage
        }
        return image
    }

    private func render(pdfPage: PDFPage) -> NSImage? {
        let bounds = pdfPage.bounds(for: .mediaBox)
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        NSColor.white.setFill()
        bounds.fill()
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }
        pdfPage.draw(with: .mediaBox, to: context)
        image.unlockFocus()
        return image
    }

    private func thumbnailData(for page: PDFPage) -> Data? {
        let thumbnail = page.thumbnail(of: CGSize(width: 260, height: 340), for: .mediaBox)
        return thumbnail.pngData(maxPixelSize: 360)
    }
}

public extension NSImage {
    func pngData(maxPixelSize: CGFloat? = nil) -> Data? {
        let image: NSImage
        if let maxPixelSize {
            let scale = min(maxPixelSize / max(size.width, size.height), 1)
            image = NSImage(size: CGSize(width: size.width * scale, height: size.height * scale))
            image.lockFocus()
            draw(in: NSRect(origin: .zero, size: image.size))
            image.unlockFocus()
        } else {
            image = self
        }

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
