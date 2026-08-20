import AppKit
import Foundation
import ImageIO
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
        static let maxPagePixelsAsCGFloat: CGFloat = CGFloat(maxPagePixels)
        static let maxPDFPageArea: CGFloat = 80_000_000
        /// OCR target is two pixels per PDF point (roughly 144 DPI), reduced
        /// further for unusually large pages by the pixel budget.
        static let ocrTargetScale: CGFloat = 2.0
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
                    blocks: [],
                    pageLabel: pdfPage.label,
                    links: pdfLinks(for: pdfPage, in: pdf, pageNumber: index + 1),
                    annotations: pdfAnnotations(for: pdfPage, pageNumber: index + 1),
                    textPositions: pdfTextPositions(for: pdfPage)
                )
            },
            outline: pdfOutline(pdf),
            metadata: pdfDocumentMetadata(pdf)
        )
        await onProgress?(document)

        for (index, page) in document.pages.enumerated() {
            try Task.checkCancellation()
            document.pages[index].ocrStatus = .processing
            await onProgress?(document)

            // Process one visual page at a time. Rendering every scanned page
            // before OCR made a 50–100 page PDF retain many large CGImages at
            // once. The bounded path keeps memory proportional to one page and
            // still preserves deterministic page order and cancellation.
            let embeddedText = pdf.page(at: index)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let pageInput = PageInput(
                pageNumber: page.pageNumber,
                pageSize: CGSize(width: page.size.width, height: page.size.height),
                embeddedText: embeddedText,
                cgImage: embeddedText.isEmpty
                    ? pdf.page(at: index).flatMap { render(pdfPage: $0)?.cgImage(forProposedRect: nil, context: nil, hints: nil) }
                    : nil
            )
            let blocks = await extractBlocks(input: pageInput).1
            document.pages[index].ocrStatus = .complete
            document.pages[index].blocks = blocks
            await onProgress?(document)
        }

        return analyzedDocument(document)
    }

    private func pdfDocumentMetadata(_ pdf: PDFDocument) -> [String: String] {
        let attributes = pdf.documentAttributes ?? [:]
        let mappings: [(String, Any?)] = [
            ("title", attributes[PDFDocumentAttribute.titleAttribute]),
            ("author", attributes[PDFDocumentAttribute.authorAttribute]),
            ("subject", attributes[PDFDocumentAttribute.subjectAttribute]),
            ("creator", attributes[PDFDocumentAttribute.creatorAttribute]),
            ("producer", attributes[PDFDocumentAttribute.producerAttribute]),
            ("keywords", attributes[PDFDocumentAttribute.keywordsAttribute])
        ]
        return mappings.reduce(into: [:]) { result, entry in
            if let value = entry.1 as? String, !value.isEmpty {
                result[entry.0] = value
            } else if let values = entry.1 as? [String], !values.isEmpty {
                result[entry.0] = values.joined(separator: ", ")
            }
        }
    }

    private func pdfOutline(_ pdf: PDFDocument) -> [OutlineItem] {
        guard let root = pdf.outlineRoot else { return [] }
        var items: [OutlineItem] = []

        func append(_ outline: PDFOutline, level: Int) {
            for index in 0..<outline.numberOfChildren {
                guard let child = outline.child(at: index),
                      let title = child.label?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !title.isEmpty,
                      let page = child.destination?.page else {
                    if let child = outline.child(at: index) {
                        append(child, level: level + 1)
                    }
                    continue
                }
                let pageIndex = pdf.index(for: page)
                guard pageIndex >= 0 else {
                    append(child, level: level + 1)
                    continue
                }
                items.append(OutlineItem(title: title, pageNumber: pageIndex + 1, level: max(1, level)))
                append(child, level: level + 1)
            }
        }

        append(root, level: 1)
        return items
    }

    private func pdfLinks(for page: PDFPage, in pdf: PDFDocument, pageNumber: Int) -> [ReaderLink] {
        page.annotations.compactMap { annotation in
            let url = annotation.url
            let targetPageNumber: Int? = annotation.destination?.page.map { pdf.index(for: $0) + 1 }
            guard url != nil || targetPageNumber != nil else { return nil }
            let bounds = annotation.bounds
            return ReaderLink(
                pageNumber: pageNumber,
                bounds: BoundingBox(x: bounds.origin.x, y: bounds.origin.y, width: bounds.width, height: bounds.height),
                label: annotation.contents,
                url: url,
                targetPageNumber: targetPageNumber
            )
        }
    }

    private func pdfAnnotations(for page: PDFPage, pageNumber: Int) -> [ReaderAnnotation] {
        page.annotations.compactMap { annotation in
            guard annotation.type?.lowercased() != "link" else { return nil }
            let bounds = annotation.bounds
            return ReaderAnnotation(
                pageNumber: pageNumber,
                type: annotation.type ?? "unknown",
                bounds: BoundingBox(x: bounds.origin.x, y: bounds.origin.y, width: bounds.width, height: bounds.height),
                contents: annotation.contents,
                fieldName: annotation.fieldName,
                value: annotation.widgetStringValue
            )
        }
    }

    private func pdfTextPositions(for page: PDFPage) -> [DocumentTextPosition] {
        // Character bounds are useful for downstream highlighting but can be
        // unexpectedly large in hostile PDFs. Keep this auxiliary data bounded
        // independently of the OCR/page budgets.
        let count = min(page.numberOfCharacters, 100_000)
        guard count > 0 else { return [] }
        return (0..<count).compactMap { index in
            let bounds = page.characterBounds(at: index)
            guard bounds.width > 0, bounds.height > 0 else { return nil }
            return DocumentTextPosition(
                characterIndex: index,
                bounds: BoundingBox(x: bounds.origin.x, y: bounds.origin.y, width: bounds.width, height: bounds.height)
            )
        }
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
        // Prefer explicit PDF bookmarks over heuristic heading outlines. The
        // latter remains the fallback for PDFs without a document outline.
        guard !document.outline.isEmpty else { return analyzed }
        var preserved = analyzed
        preserved.outline = document.outline
        return preserved
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
        let requestedScale = ImportBudget.ocrTargetScale
        let area = max(1, bounds.width * bounds.height)
        let budgetScale = sqrt(ImportBudget.maxPagePixelsAsCGFloat / area)
        let scale = max(1, min(requestedScale, budgetScale))
        let pixelWidth = max(1, Int((bounds.width * scale).rounded(.up)))
        let pixelHeight = max(1, Int((bounds.height * scale).rounded(.up)))
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }
        context.beginPDFPage(nil)
        context.translateBy(x: 0, y: bounds.height * scale)
        context.scaleBy(x: 1, y: -1)
        context.scaleBy(x: scale, y: scale)
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
        guard let tiff = tiffRepresentation,
              let imageSource = CGImageSourceCreateWithData(tiff as CFData, nil) else {
            return nil
        }

        let source: CGImage?
        if let maxPixelSize {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize.rounded()))
            ]
            source = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
        } else {
            source = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        }

        guard let source,
              let destinationData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(destinationData, "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, source, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return destinationData as Data
    }
}
