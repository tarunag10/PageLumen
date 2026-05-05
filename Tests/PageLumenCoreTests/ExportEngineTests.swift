import PDFKit
import XCTest
@testable import PageLumenCore

final class ExportEngineTests: XCTestCase {
    func testMarkdownExportIncludesHeadingsPageMarkersTablesAndFigures() {
        let document = SampleDataFactory.makeDemoDocument()

        let markdown = ExportEngine().markdown(for: document, options: .full)

        XCTAssertTrue(markdown.contains("# PageLumen Demo"))
        XCTAssertTrue(markdown.contains("## Page 1"))
        XCTAssertTrue(markdown.contains("### IMPORT FLOW"))
        XCTAssertTrue(markdown.contains("| Item | Status |"))
        XCTAssertTrue(markdown.contains("Figure: The chart appears to show"))
    }

    func testHTMLExportUsesSemanticElements() {
        let document = SampleDataFactory.makeDemoDocument()

        let html = ExportEngine().html(for: document, options: .full)

        XCTAssertTrue(html.contains("<main>"))
        XCTAssertTrue(html.contains("<h1>PageLumen Demo</h1>"))
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<figure>"))
    }

    func testPDFExportReturnsPDFData() {
        let document = SampleDataFactory.makeDemoDocument()

        let data = ExportEngine().data(for: document, format: .pdf, options: .full)
        let prefix = String(data: data.prefix(5), encoding: .utf8)

        XCTAssertEqual(prefix, "%PDF-")
        XCTAssertGreaterThan(data.count, 100)
    }

    func testPDFExportPaginatesLongReadableText() {
        let blocks = (1...90).map { index in
            TextBlock(
                pageNumber: 1,
                type: .paragraph,
                text: "Paragraph \(index): PageLumen should keep exported accessible PDF text readable instead of clipping it from the first page.",
                bounds: BoundingBox(x: 72, y: Double(index * 22), width: 460, height: 18),
                confidence: 0.95,
                readingOrderIndex: index
            )
        }
        let document = ReaderDocument(
            title: "Long Export",
            sourceType: .sample,
            pages: [
                ReaderPage(
                    pageNumber: 1,
                    size: PageSize(width: 612, height: 792),
                    blocks: blocks
                )
            ]
        )

        let data = ExportEngine().pdfData(for: document, options: .full)
        let pdf = PDFDocument(data: data)

        XCTAssertNotNil(pdf)
        XCTAssertGreaterThan(pdf?.pageCount ?? 0, 1)
        XCTAssertTrue(pdf?.string?.contains("Paragraph 90") == true)
    }
}
