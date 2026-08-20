import AppKit
import PDFKit
import XCTest
@testable import PageLumenCore

final class DocumentProcessorTests: XCTestCase {
    @MainActor
    func testPNGDataUsesBoundedImageIOThumbnail() throws {
        let image = NSImage(size: CGSize(width: 1_200, height: 800))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(origin: .zero, size: image.size).fill()
        image.unlockFocus()

        guard let data = image.pngData(maxPixelSize: 160),
              let thumbnail = NSImage(data: data) else {
            XCTFail("Expected PNG thumbnail data")
            return
        }

        XCTAssertLessThanOrEqual(thumbnail.size.width, 160)
        XCTAssertLessThanOrEqual(thumbnail.size.height, 160)
        XCTAssertGreaterThan(data.count, 0)
    }

    @MainActor
    func testEmbeddedPDFTextIsExtractedWithoutOCRFallback() async throws {
        let url = try makePDF(containing: "Embedded PDF text for PageLumen")
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try await DocumentProcessor().process(url: url)

        XCTAssertEqual(document.sourceType, .pdf)
        XCTAssertEqual(document.pageCount, 1)
        XCTAssertTrue(document.allBlocks.map(\.text).joined(separator: " ").contains("Embedded PDF text for PageLumen"))
        XCTAssertTrue(document.allBlocks.contains { $0.metadata["source"] == "embedded-pdf" })
        XCTAssertFalse(document.pages[0].textPositions.isEmpty)
        XCTAssertEqual(document.pages[0].textPositions.first?.characterIndex, 0)
    }

    @MainActor
    func testPDFMetadataIsRetainedAlongsideExtractedContent() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        let source = try makePDF(containing: "Metadata fixture")
        defer { try? FileManager.default.removeItem(at: url); try? FileManager.default.removeItem(at: source) }
        guard let pdf = PDFDocument(url: source) else {
            XCTFail("Could not open generated PDF")
            return
        }
        pdf.documentAttributes = [
            PDFDocumentAttribute.titleAttribute: "Metadata title",
            PDFDocumentAttribute.authorAttribute: "PageLumen test"
        ]
        XCTAssertTrue(pdf.write(to: url))

        let document = try await DocumentProcessor().process(url: url)

        XCTAssertEqual(document.metadata["title"], "Metadata title")
        XCTAssertEqual(document.metadata["author"], "PageLumen test")
        XCTAssertTrue(document.allBlocks.map(\.text).joined(separator: " ").contains("Metadata fixture"))
    }

    @MainActor
    func testPDFBookmarksBecomeNestedOutlineItems() async throws {
        let source = try makePDF(containingPages: ["Introduction", "Details"])
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        defer { try? FileManager.default.removeItem(at: source); try? FileManager.default.removeItem(at: url) }
        guard let pdf = PDFDocument(url: source),
              let firstPage = pdf.page(at: 0),
              let secondPage = pdf.page(at: 1) else {
            XCTFail("Could not open generated PDF")
            return
        }
        let root = PDFOutline()
        let introduction = PDFOutline()
        introduction.label = "Introduction"
        introduction.destination = PDFDestination(page: firstPage, at: .zero)
        let details = PDFOutline()
        details.label = "Details"
        details.destination = PDFDestination(page: secondPage, at: .zero)
        introduction.insertChild(details, at: 0)
        root.insertChild(introduction, at: 0)
        pdf.outlineRoot = root
        XCTAssertTrue(pdf.write(to: url))

        let document = try await DocumentProcessor().process(url: url)

        XCTAssertEqual(document.outline.map(\.title), ["Introduction", "Details"])
        XCTAssertEqual(document.outline.map(\.pageNumber), [1, 2])
        XCTAssertEqual(document.outline.map(\.level), [1, 2])
    }

    @MainActor
    func testPDFLinkAnnotationsAreRetainedWithBoundsAndURL() async throws {
        let source = try makePDF(containing: "Link target")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        defer { try? FileManager.default.removeItem(at: source); try? FileManager.default.removeItem(at: url) }
        guard let pdf = PDFDocument(url: source), let page = pdf.page(at: 0) else {
            XCTFail("Could not open generated PDF")
            return
        }
        let annotation = PDFAnnotation(
            bounds: CGRect(x: 40, y: 60, width: 140, height: 24),
            forType: .link,
            withProperties: nil
        )
        annotation.url = URL(string: "https://example.com/page")
        annotation.contents = "Read more"
        page.addAnnotation(annotation)
        XCTAssertTrue(pdf.write(to: url))

        let document = try await DocumentProcessor().process(url: url)
        let link = try XCTUnwrap(document.pages[0].links.first)

        XCTAssertEqual(link.label, "Read more")
        XCTAssertEqual(link.url?.absoluteString, "https://example.com/page")
        XCTAssertEqual(link.bounds, BoundingBox(x: 40, y: 60, width: 140, height: 24))
    }

    @MainActor
    func testPDFFormAndNonLinkAnnotationsAreRetained() async throws {
        let source = try makePDF(containing: "Form fixture")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        defer { try? FileManager.default.removeItem(at: source); try? FileManager.default.removeItem(at: url) }
        guard let pdf = PDFDocument(url: source), let page = pdf.page(at: 0) else {
            XCTFail("Could not open generated PDF")
            return
        }
        let note = PDFAnnotation(bounds: CGRect(x: 30, y: 40, width: 80, height: 20), forType: .text, withProperties: nil)
        note.contents = "Reviewer note"
        page.addAnnotation(note)
        let field = PDFAnnotation(bounds: CGRect(x: 30, y: 80, width: 180, height: 24), forType: .widget, withProperties: nil)
        field.fieldName = "FullName"
        field.widgetStringValue = "Alice"
        page.addAnnotation(field)
        XCTAssertTrue(pdf.write(to: url))

        let document = try await DocumentProcessor().process(url: url)
        let annotations = document.pages[0].annotations

        XCTAssertTrue(annotations.contains { $0.type.lowercased() == "text" && $0.contents == "Reviewer note" })
        XCTAssertTrue(annotations.contains { $0.type.lowercased() == "widget" && $0.fieldName == "FullName" && $0.value == "Alice" })
        XCTAssertTrue(document.pages[0].links.isEmpty)
    }

    func testUnsupportedFileThrowsReadableError() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")
        try? "hello".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try await DocumentProcessor().process(url: url)
            XCTFail("Expected unsupported files to throw")
        } catch let error as DocumentProcessorError {
            XCTAssertEqual(error.localizedDescription, "PageLumen does not support \(url.lastPathComponent).")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testMalformedPDFFailsWithoutLeakingPathOrPayload() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("private-document-(UUID().uuidString)")
            .appendingPathExtension("pdf")
        let secret = "PRIVATE OCR CONTENT (UUID().uuidString)"
        try Data("not a pdf (secret)".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try await DocumentProcessor().process(url: url)
            XCTFail("Expected malformed PDFs to throw")
        } catch let error as DocumentProcessorError {
            let description = error.localizedDescription
            XCTAssertEqual(description, "The PDF (url.lastPathComponent) could not be opened.")
            XCTAssertFalse(description.contains(url.path), "Errors must not expose the local path")
            XCTAssertFalse(description.contains(secret), "Errors must not expose document payloads")
        } catch {
            XCTFail("Unexpected error: (error)")
        }
    }

    @MainActor
    func testMalformedImageFailsWithoutLeakingPathOrPayload() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("private-image-(UUID().uuidString)")
            .appendingPathExtension("png")
        let secret = "PRIVATE OCR CONTENT (UUID().uuidString)"
        try Data("not an image (secret)".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try await DocumentProcessor().process(url: url)
            XCTFail("Expected malformed images to throw")
        } catch let error as DocumentProcessorError {
            let description = error.localizedDescription
            XCTAssertEqual(description, "The selected image could not be decoded.")
            XCTAssertFalse(description.contains(url.path), "Errors must not expose the local path")
            XCTAssertFalse(description.contains(secret), "Errors must not expose document payloads")
        } catch {
            XCTFail("Unexpected error: (error)")
        }
    }

    @MainActor
    func testPDFOverPageBudgetThrowsReadableError() async throws {
        let url = try makePDF(containingPages: Array(repeating: "Budget page", count: 101))
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try await DocumentProcessor().process(url: url)
            XCTFail("Expected oversized PDFs to throw")
        } catch let error as DocumentProcessorError {
            XCTAssertEqual(error.localizedDescription, "The selected document is too large to process safely.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testTenPageImportCompletesWithinWallTimeBaseline() async throws {
        let url = try makePDF(containingPages: (1...10).map { "Baseline page \($0)" })
        defer { try? FileManager.default.removeItem(at: url) }
        let start = Date()

        let document = try await DocumentProcessor().process(url: url)

        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(document.pageCount, 10)
        XCTAssertEqual(document.processingStatus, .complete)
        XCTAssertLessThan(elapsed, 30, "10-page embedded-text baseline exceeded 30 seconds: \(elapsed)s")
    }

    @MainActor
    func testFiftyPageImportCompletesWithinWallTimeBaseline() async throws {
        let url = try makePDF(containingPages: (1...50).map { index in
            index.isMultiple(of: 2) ? "Mixed baseline text page \(index)" : "Baseline page \(index)"
        })
        defer { try? FileManager.default.removeItem(at: url) }
        let start = Date()

        let document = try await DocumentProcessor().process(url: url)

        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(document.pageCount, 50)
        XCTAssertEqual(document.processingStatus, .complete)
        XCTAssertLessThan(elapsed, 90, "50-page embedded-text baseline exceeded 90 seconds: \(elapsed)s")
    }

    @MainActor
    func testPDFProcessingPublishesPerPageProgressSnapshots() async throws {
        let url = try makePDF(containingPages: ["First page text", "Second page text"])
        defer { try? FileManager.default.removeItem(at: url) }
        var snapshots: [ReaderDocument] = []

        let document = try await DocumentProcessor().process(url: url) { snapshot in
            snapshots.append(snapshot)
        }

        XCTAssertEqual(document.processingStatus, .complete)
        XCTAssertEqual(document.pages.map(\.ocrStatus), [.complete, .complete])
        XCTAssertTrue(snapshots.contains { $0.processingStatus == .processing && $0.pages.map(\.ocrStatus) == [.pending, .pending] })
        XCTAssertTrue(snapshots.contains { $0.pages.map(\.ocrStatus) == [.processing, .pending] })
        XCTAssertTrue(snapshots.contains { $0.pages.map(\.ocrStatus) == [.complete, .pending] })
        XCTAssertTrue(snapshots.contains { $0.pages.map(\.ocrStatus) == [.complete, .processing] })
        XCTAssertEqual(snapshots.last?.pages.map(\.ocrStatus), [.complete, .complete])
        XCTAssertTrue(snapshots.flatMap(\.pages).contains { $0.thumbnailData != nil })
    }

    @MainActor
    func testSecurityScopedPDFImportProcessesNormally() async throws {
        let url = try makePDF(containing: "Security scoped PDF text for PageLumen")
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try await DocumentProcessor().process(securityScopedURL: url)

        XCTAssertEqual(document.sourceType, .pdf)
        XCTAssertTrue(document.allBlocks.map(\.text).joined(separator: " ").contains("Security scoped PDF text for PageLumen"))
    }

    @MainActor
    func testStructuredRecognitionProducesBlocks() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        let size = CGSize(width: 400, height: 200)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 24), .foregroundColor: NSColor.black]
        NSAttributedString(string: "Structured test text", attributes: attrs).draw(at: CGPoint(x: 20, y: 100))
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Could not create test image")
            return
        }
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try await DocumentProcessor().process(url: url)
        let allText = document.allBlocks.map(\.text).joined(separator: " ")
        XCTAssertTrue(allText.contains("Structured") || allText.contains("test"), "Expected some recognized text, got: \(allText)")
    }

    @MainActor
    private func makePDF(containing text: String) throws -> URL {
        try makePDF(containingPages: [text])
    }

    @MainActor
    private func makePDF(containingPages pages: [String]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        let document = PDFDocument()

        for pageText in pages {
            let pageRect = NSRect(x: 0, y: 0, width: 612, height: 792)
            let view = NSTextView(frame: pageRect)
            view.string = pageText
            view.font = NSFont.systemFont(ofSize: 18)
            let data = view.dataWithPDF(inside: pageRect)
            guard let source = PDFDocument(data: data), let page = source.page(at: 0) else {
                XCTFail("Could not create PDF page")
                continue
            }
            document.insert(page, at: document.pageCount)
        }

        guard document.write(to: url) else {
            XCTFail("Could not write PDF")
            return url
        }
        return url
    }
}
