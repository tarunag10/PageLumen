import AppKit
import XCTest
@testable import SightlineCore

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
            XCTAssertEqual(error.localizedDescription, "Sightline Reader does not support \(url.lastPathComponent).")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    private func makePDF(containing text: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        let pageRect = NSRect(x: 0, y: 0, width: 612, height: 792)
        let view = NSTextView(frame: pageRect)
        view.string = text
        view.font = NSFont.systemFont(ofSize: 18)
        let data = view.dataWithPDF(inside: pageRect)
        try data.write(to: url)
        return url
    }
}
