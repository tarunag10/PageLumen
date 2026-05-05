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
}
