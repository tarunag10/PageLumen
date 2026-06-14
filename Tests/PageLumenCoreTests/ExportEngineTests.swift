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

    func testMarkdownSnapshotMatchesExpected() {
        let document = SampleDataFactory.makeDemoDocument()
        let markdown = ExportEngine().markdown(for: document, options: .full)

        let expected = """
        # PageLumen Demo

        ## Page 1

        ### IMPORT FLOW

        PageLumen turns inaccessible visual documents into readable, structured, audio-friendly, and exportable content.

        | Item | Status |
        | --- | --- |
        | PDF import | Ready |
        | OCR confidence | Visible |

        > This table appears to contain 3 rows and 2 columns. The visible header or first row reads: Item, Status.

        Figure: The chart appears to show the app workflow moving from extraction to review and export.

        """

        XCTAssertEqual(markdown, expected)
    }

    func testTaggedHTMLSnapshotMatchesExpected() {
        let document = SampleDataFactory.makeDemoDocument()
        let html = ExportEngine().taggedHTML(for: document, options: .full)

        let normalized = Self.normalize(html)
        let expected = Self.normalize(Self.taggedHTMLExpected)
        XCTAssertEqual(normalized, expected)
    }

    func testCSVSnapshotMatchesExpected() {
        let document = SampleDataFactory.makeDemoDocument()
        let csv = ExportEngine().csv(for: document, options: .full)

        let expected = """
        Page,Table,Row,Column,Value
        1,1,1,1,Item
        1,1,1,2,Status
        1,1,2,1,PDF import
        1,1,2,2,Ready
        1,1,3,1,OCR confidence
        1,1,3,2,Visible
        """

        XCTAssertEqual(csv, expected)
    }

    private static func normalize(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"block-[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#,
            with: "block-UUID",
            options: .regularExpression
        )
    }

    private static let taggedHTMLExpected = """
    <!doctype html>
    <html lang="en" data-pagelumen-export="tagged-html">
    <head>
    <meta charset="utf-8">
    <meta name="generator" content="PageLumen">
    <title>PageLumen Demo</title>
    </head>
    <body>
    <a href="#content">Skip to content</a>
    <main id="content">
    <h1>PageLumen Demo</h1>
    <aside aria-label="Accessibility export status">
    <p>Ready for tagged export. No structural issues were found by PageLumen's automated checks.</p>
    </aside>
    <section aria-labelledby="page-1-heading" data-page="1">
    <h2 id="page-1-heading">Page 1</h2>
    <h3 id="block-UUID" data-page="1">IMPORT FLOW</h3>
    <p id="block-UUID" data-page="1" data-confidence="0.95">PageLumen turns inaccessible visual documents into readable, structured, audio-friendly, and exportable content.</p>
    <table data-page="1">
    <thead><tr><th scope="col">Item</th><th scope="col">Status</th></tr></thead>
    <tbody>
    <tr><td>PDF import</td><td>Ready</td></tr>
    <tr><td>OCR confidence</td><td>Visible</td></tr>
    </tbody></table>
    <p><strong>Table note:</strong> This table appears to contain 3 rows and 2 columns. The visible header or first row reads: Item, Status.</p>
    <figure id="block-UUID" data-page="1"><div role="img" aria-label="The chart appears to show the app workflow moving from extraction to review and export."></div><figcaption>The chart appears to show the app workflow moving from extraction to review and export.</figcaption></figure>
    </section>
    </main>
    </body>
    </html>
    """
}
