import AppKit
import PDFKit
import XCTest
@testable import PageLumenCore

final class DocumentProcessorTests: XCTestCase {
    @MainActor
    func testEmbeddedPDFTextIsExtractedWithoutOCRFallback() async throws {
        let url = try makePDF(containing: "Embedded PDF text for PageLumen")
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try await DocumentProcessor().process(url: url)

        XCTAssertEqual(document.sourceType, .pdf)
        XCTAssertEqual(document.pageCount, 1)
        XCTAssertTrue(document.allBlocks.map(\.text).joined(separator: " ").contains("Embedded PDF text for PageLumen"))
        XCTAssertTrue(document.allBlocks.contains { $0.metadata["source"] == "embedded-pdf" })
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
