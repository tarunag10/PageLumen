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
