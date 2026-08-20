import Markdown
import XCTest
@testable import PageLumenCore

/// Validates that PageLumen's deterministic Markdown remains structurally
/// consumable by the Swift Markdown AST without putting the parser in the app.
final class MarkdownContractTests: XCTestCase {
    func testDemoMarkdownParsesHeadingsTableAndBlockQuote() {
        let markdown = ExportEngine().markdown(
            for: SampleDataFactory.makeDemoDocument(),
            options: .full
        )

        let document = Document(parsing: markdown)
        let topLevel = Array(document.children)

        let headings = topLevel.compactMap { $0 as? Heading }
        XCTAssertTrue(headings.contains { $0.level == 1 })
        XCTAssertTrue(headings.contains { $0.level == 2 })
        XCTAssertTrue(headings.contains { $0.level == 3 })

        let title = headings.first { $0.level == 1 }
        XCTAssertEqual((title?.child(at: 0) as? Text)?.string, "PageLumen Demo")

        let table = topLevel.compactMap { $0 as? Table }.first
        XCTAssertEqual(table?.maxColumnCount, 2)
        XCTAssertEqual(table?.head.childCount, 2)

        XCTAssertTrue(topLevel.contains { $0 is BlockQuote })
    }

    func testExportContractAcceptsDemoAndStablePageMarkers() {
        let markdown = ExportEngine().markdown(
            for: SampleDataFactory.makeDemoDocument(),
            options: .full
        )

        let validation = MarkdownExportContract.validate(markdown, expectedPageNumbers: [1])

        XCTAssertTrue(validation.isValid, validation.issues.joined(separator: ", "))
        XCTAssertTrue(validation.issues.isEmpty)
    }

    func testExportEscapesTablePipesAndNormalizesLineBreaks() {
        var document = SampleDataFactory.makeDemoDocument()
        document.title = "Title\r\nwith a line"
        document.pages[0].tables[0].rows[1][0] = "Cell | value\ncontinued"

        let markdown = ExportEngine().markdown(for: document, options: .full)

        XCTAssertTrue(markdown.contains("# Title with a line"))
        XCTAssertTrue(markdown.contains("Cell \\| value continued"))
        XCTAssertFalse(markdown.contains("\r"))
        XCTAssertFalse(markdown.contains("Cell | value"))
        XCTAssertTrue(MarkdownExportContract.validate(markdown).isValid)
    }

    func testExportContractRejectsUnstableOrMalformedStructure() {
        let malformed = "# Title\n\n## Page 2\n\n| A | B |\n| --- |\n"

        let validation = MarkdownExportContract.validate(malformed, expectedPageNumbers: [1])

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.issues.contains("markdown.page-markers-not-deterministic"))
        XCTAssertTrue(validation.issues.contains("markdown.table-column-count-mismatch"))
    }

    func testDialectPolicyReportsUnsupportedTablesWithoutRewritingInput() {
        let markdown = "# Title\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n"
        let validation = MarkdownExportContract.validate(markdown, dialect: .commonMark)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.issues.contains("markdown.tables-unsupported-by-dialect"))
        XCTAssertTrue(MarkdownDialect.commonMark.preservesUnsupportedSyntax)
        XCTAssertTrue(markdown.contains("| 1 | 2 |"))
    }
}
