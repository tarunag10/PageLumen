import AppKit
import Foundation
import PDFKit
import Vision

public enum DocumentProcessorError: LocalizedError, Sendable {
    case unsupportedFile(URL)
    case unreadableImage
    case unreadablePDF(URL)
    case documentTooLarge

    public var errorDescription: String? {
        switch self {
        case .unsupportedFile(let url):
            return "PageLumen does not support \(url.lastPathComponent)."
        case .unreadableImage:
            return "The selected image could not be decoded."
        case .unreadablePDF(let url):
            return "The PDF \(url.lastPathComponent) could not be opened."
        case .documentTooLarge:
            return "The selected document is too large to process safely."
        }
    }
}

public typealias DocumentProcessingProgressHandler = @MainActor @Sendable (ReaderDocument) async -> Void

public final class DocumentProcessor: DocumentImporting, @unchecked Sendable {
    private enum ImportBudget {
        static let maxFileBytes: UInt64 = 200 * 1_024 * 1_024
        static let maxPDFPages = 100
        static let maxPagePixels: UInt64 = 50_000_000
        static let maxPDFPageArea: CGFloat = 80_000_000
    }

    public static let supportedExtensions: [String] = [
        "pdf", "png", "jpg", "jpeg", "tif", "tiff", "heic"
    ]

    private let analyzer: LayoutAnalyzer

    public init(profile: OCRProfile = .general) {
        self.analyzer = LayoutAnalyzer(profile: profile)
    }

    public init(analyzer: LayoutAnalyzer) {
        self.analyzer = analyzer
    }

    public func process(
        url: URL,
        onProgress: DocumentProcessingProgressHandler? = nil
    ) async throws -> ReaderDocument {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            try validateFileBudget(url)
            return try await processPDF(url: url, onProgress: onProgress)
        }

        if Self.supportedExtensions.contains(ext) {
            try validateFileBudget(url)
            let image = try loadImage(from: url)
            return try await process(image: image, title: url.deletingPathExtension().lastPathComponent, sourceType: .image, sourceURL: url, onProgress: onProgress)
        }

        throw DocumentProcessorError.unsupportedFile(url)
    }

    public func process(
        securityScopedURL url: URL,
        onProgress: DocumentProcessingProgressHandler? = nil
    ) async throws -> ReaderDocument {
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        return try await process(url: url, onProgress: onProgress)
    }

    public func processClipboardImage(
        _ image: NSImage,
        onProgress: DocumentProcessingProgressHandler? = nil
    ) async throws -> ReaderDocument {
        try await process(image: image, title: "Clipboard Image", sourceType: .clipboard, sourceURL: nil, onProgress: onProgress)
    }

    private func processPDF(url: URL, onProgress: DocumentProcessingProgressHandler?) async throws -> ReaderDocument {
        guard let pdf = PDFDocument(url: url) else {
            throw DocumentProcessorError.unreadablePDF(url)
        }
        try validatePDFBudget(pdf)

        var document = ReaderDocument(
            title: url.deletingPathExtension().lastPathComponent,
            sourceType: .pdf,
            sourceURL: url,
            processingStatus: .processing,
            pages: (0..<pdf.pageCount).compactMap { index in
                guard let pdfPage = pdf.page(at: index) else { return nil }
                let bounds = pdfPage.bounds(for: .mediaBox)
                return ReaderPage(
                    pageNumber: index + 1,
                    size: PageSize(width: bounds.width, height: bounds.height),
                    thumbnailData: thumbnailData(for: pdfPage),
                    ocrStatus: .pending,
                    blocks: []
                )
            }
        )
        await onProgress?(document)

        let pageInputs: [PageInput] = (0..<pdf.pageCount).compactMap { index in
            guard let pdfPage = pdf.page(at: index) else { return nil }
            let pageNumber = index + 1
            let bounds = pdfPage.bounds(for: .mediaBox)
            let embeddedText = pdfPage.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let cgImage: CGImage? = embeddedText.isEmpty
                ? render(pdfPage: pdfPage)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
                : nil
            return PageInput(pageNumber: pageNumber, pageSize: bounds.size, embeddedText: embeddedText, cgImage: cgImage)
        }
        try Task.checkCancellation()

        let results: [Int: [TextBlock]] = await withTaskGroup(of: (Int, [TextBlock]).self) { group in
            let cap = max(1, ProcessInfo.processInfo.activeProcessorCount / 2)
            var iterator = pageInputs.makeIterator()
            var inFlight = 0

            while inFlight < cap, let next = iterator.next() {
                let capture = next
                group.addTask { [weak self] in
                    guard let self else { return (capture.pageNumber, [TextBlock]()) }
                    return await self.extractBlocks(input: capture)
                }
                inFlight += 1
            }

            var collected: [Int: [TextBlock]] = [:]
            for await result in group {
                collected[result.0] = result.1
                inFlight -= 1
                if let next = iterator.next() {
                    let capture = next
                    group.addTask { [weak self] in
                        guard let self else { return (capture.pageNumber, [TextBlock]()) }
                        return await self.extractBlocks(input: capture)
                    }
                    inFlight += 1
                }
            }
            return collected
        }

        for (index, page) in document.pages.enumerated() {
            try Task.checkCancellation()
            document.pages[index].ocrStatus = .processing
            await onProgress?(document)

            let blocks = results[page.pageNumber] ?? fallbackBlocks(pageNumber: page.pageNumber, pageSize: CGSize(width: page.size.width, height: page.size.height))
            document.pages[index].ocrStatus = .complete
            document.pages[index].blocks = blocks
            await onProgress?(document)
        }

        return analyzedDocument(document)
    }

    private struct PageInput: Sendable {
        let pageNumber: Int
        let pageSize: CGSize
        let embeddedText: String
        let cgImage: CGImage?
    }

    private func extractBlocks(input: PageInput) async -> (Int, [TextBlock]) {
        if !input.embeddedText.isEmpty {
            let blocks = makeBlocks(from: input.embeddedText, pageNumber: input.pageNumber, pageSize: input.pageSize, source: BlockSource.embeddedPDF.metadataValue, confidence: 0.98)
            return (input.pageNumber, blocks)
        }
        if let cgImage = input.cgImage {
            if #available(macOS 26.0, *),
               let structuredBlocks = try? await recognizeStructured(in: cgImage, pageNumber: input.pageNumber, pageSize: input.pageSize),
               !structuredBlocks.isEmpty {
                return (input.pageNumber, structuredBlocks)
            }
            do {
                let blocks = try await recognizeText(in: cgImage, pageNumber: input.pageNumber, pageSize: input.pageSize)
                return (input.pageNumber, blocks)
            } catch {
                return (input.pageNumber, fallbackBlocks(pageNumber: input.pageNumber, pageSize: input.pageSize))
            }
        }
        return (input.pageNumber, fallbackBlocks(pageNumber: input.pageNumber, pageSize: input.pageSize))
    }

    private func fallbackBlocks(pageNumber: Int, pageSize: CGSize) -> [TextBlock] {
        [TextBlock(
            pageNumber: pageNumber,
            type: .unknown,
            text: "No readable text was found on this page.",
            bounds: BoundingBox(x: 0, y: 0, width: pageSize.width, height: 32),
            confidence: 0.0
        )]
    }

    private func analyzedDocument(_ document: ReaderDocument) -> ReaderDocument {
        var completed = document
        completed.processingStatus = .complete
        let analyzed = analyzer.analyze(document: completed)
        return analyzed
    }

    private func process(
        image: NSImage,
        title: String,
        sourceType: SourceType,
        sourceURL: URL?,
        onProgress: DocumentProcessingProgressHandler?
    ) async throws -> ReaderDocument {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw DocumentProcessorError.unreadableImage
        }
        try validateImageBudget(cgImage)

        let pageSize = CGSize(width: cgImage.width, height: cgImage.height)
        var document = ReaderDocument(
            title: title,
            sourceType: sourceType,
            sourceURL: sourceURL,
            processingStatus: .processing,
            pages: [
                ReaderPage(
                    pageNumber: 1,
                    size: PageSize(width: pageSize.width, height: pageSize.height),
                    thumbnailData: image.pngData(maxPixelSize: 360),
                    ocrStatus: .processing,
                    blocks: []
                )
            ]
        )
        await onProgress?(document)
        try Task.checkCancellation()

        let blocks: [TextBlock]
        if #available(macOS 26.0, *),
           let structuredBlocks = try? await recognizeStructured(in: cgImage, pageNumber: 1, pageSize: pageSize),
           !structuredBlocks.isEmpty {
            blocks = structuredBlocks
        } else {
            blocks = try await recognizeText(in: cgImage, pageNumber: 1, pageSize: pageSize)
        }
        document.pages[0].ocrStatus = .complete
        document.pages[0].blocks = blocks
        document.processingStatus = .complete

        let analyzed = analyzer.analyze(document: document)
        await onProgress?(analyzed)
        return analyzed
    }

    @available(macOS 26.0, *)
    private func recognizeStructured(in cgImage: CGImage, pageNumber: Int, pageSize: CGSize) async throws -> [TextBlock] {
        var request = Vision.RecognizeDocumentsRequest()
        request.textRecognitionOptions.automaticallyDetectLanguage = true
        request.textRecognitionOptions.useLanguageCorrection = true

        let observations = try await request.perform(on: cgImage, orientation: .up)

        var blocks: [TextBlock] = []
        var index = 0
        for observation in observations {
            let container = observation.document

            if let title = container.title {
                let text = title.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    blocks.append(TextBlock(
                        pageNumber: pageNumber,
                        type: .heading,
                        text: text,
                        bounds: boundingBox(for: title.boundingRegion, pageSize: pageSize),
                        confidence: Double(observation.confidence),
                        readingOrderIndex: index,
                        metadata: [
                            "source": BlockSource.visionOCR.metadataValue,
                            "structured-recognition": "title"
                        ]
                    ))
                    index += 1
                }
            }

            for paragraph in container.paragraphs {
                let text = paragraph.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                blocks.append(TextBlock(
                    pageNumber: pageNumber,
                    type: .paragraph,
                    text: text,
                    bounds: boundingBox(for: paragraph.boundingRegion, pageSize: pageSize),
                    confidence: Double(observation.confidence),
                    readingOrderIndex: index,
                    metadata: [
                        "source": BlockSource.visionOCR.metadataValue,
                        "structured-recognition": "paragraph"
                    ]
                ))
                index += 1
            }
        }

        return blocks
    }

    @available(macOS 26.0, *)
    private func boundingBox(for region: Vision.NormalizedRegion, pageSize: CGSize) -> BoundingBox {
        let points = region.normalizedPoints
        guard !points.isEmpty else {
            return BoundingBox(x: 0, y: 0, width: 0, height: 0)
        }
        var minX: Float = .greatestFiniteMagnitude
        var minY: Float = .greatestFiniteMagnitude
        var maxX: Float = -.greatestFiniteMagnitude
        var maxY: Float = -.greatestFiniteMagnitude
        for point in points {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        return BoundingBox(
            x: CGFloat(minX) * pageSize.width,
            y: CGFloat(1 - maxY) * pageSize.height,
            width: CGFloat(maxX - minX) * pageSize.width,
            height: CGFloat(maxY - minY) * pageSize.height
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
                        metadata: ["source": BlockSource.visionOCR.metadataValue]
                    )
                }
                continuation.resume(returning: blocks)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let userLanguages: [String]
            if #available(macOS 13, *) {
                userLanguages = Locale.preferredLanguages
            } else {
                userLanguages = ["en-US"]
            }
            request.recognitionLanguages = userLanguages
            request.automaticallyDetectsLanguage = true

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

    private func validateFileBudget(_ url: URL) throws {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .totalFileSizeKey])
        let byteCount = values?.totalFileSize ?? values?.fileSize ?? 0
        if byteCount > ImportBudget.maxFileBytes {
            throw DocumentProcessorError.documentTooLarge
        }
    }

    private func validatePDFBudget(_ pdf: PDFDocument) throws {
        if pdf.pageCount > ImportBudget.maxPDFPages {
            throw DocumentProcessorError.documentTooLarge
        }

        for index in 0..<pdf.pageCount {
            guard let page = pdf.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            if bounds.width * bounds.height > ImportBudget.maxPDFPageArea {
                throw DocumentProcessorError.documentTooLarge
            }
        }
    }

    private func validateImageBudget(_ image: CGImage) throws {
        let pixels = UInt64(image.width) * UInt64(image.height)
        if pixels > ImportBudget.maxPagePixels {
            throw DocumentProcessorError.documentTooLarge
        }
    }

    private func render(pdfPage: PDFPage) -> NSImage? {
        let bounds = pdfPage.bounds(for: .mediaBox)
        guard let context = CGContext(
            data: nil,
            width: Int(bounds.width),
            height: Int(bounds.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }
        context.beginPDFPage(nil)
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        NSColor.white.setFill()
        bounds.fill()
        pdfPage.draw(with: .mediaBox, to: context)
        context.endPDFPage()
        guard let cgImage = context.makeImage() else { return nil }
        return NSImage(cgImage: cgImage, size: bounds.size)
    }

    private func thumbnailData(for page: PDFPage) -> Data? {
        let thumbnail = page.thumbnail(of: CGSize(width: 260, height: 340), for: .mediaBox)
        return thumbnail.pngData(maxPixelSize: 360)
    }
}

public extension NSImage {
    func pngData(maxPixelSize: CGFloat? = nil) -> Data? {
        let source: NSImage
        if let maxPixelSize {
            // TODO: Replace lockFocus-based resize with a CGImageSourceCreateThumbnailAtIndex
            // + CGImageDestination path so we can avoid retaining a backing bitmap the size of
            // the page and skip the main-thread AppKit round-trip.
            let scale = min(maxPixelSize / max(size.width, size.height), 1)
            source = NSImage(size: CGSize(width: size.width * scale, height: size.height * scale))
            source.lockFocus()
            draw(in: NSRect(origin: .zero, size: source.size))
            source.unlockFocus()
        } else {
            source = self
        }

        guard let tiff = source.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
