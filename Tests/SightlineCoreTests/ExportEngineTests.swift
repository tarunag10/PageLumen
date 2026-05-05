import XCTest
@testable import SightlineCore

final class ExportEngineTests: XCTestCase {
    func testMarkdownExportIncludesHeadingsPageMarkersTablesAndFigures() {
        let document = SampleDataFactory.makeDemoDocument()

        let markdown = ExportEngine().markdown(for: document, options: .full)

        XCTAssertTrue(markdown.contains("# Sightline Reader Demo"))
        XCTAssertTrue(markdown.contains("## Page 1"))
        XCTAssertTrue(markdown.contains("### IMPORT FLOW"))
        XCTAssertTrue(markdown.contains("| Item | Status |"))
        XCTAssertTrue(markdown.contains("Figure: The chart appears to show"))
    }

    func testHTMLExportUsesSemanticElements() {
        let document = SampleDataFactory.makeDemoDocument()

        let html = ExportEngine().html(for: document, options: .full)

        XCTAssertTrue(html.contains("<main>"))
        XCTAssertTrue(html.contains("<h1>Sightline Reader Demo</h1>"))
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<figure>"))
    }
}
