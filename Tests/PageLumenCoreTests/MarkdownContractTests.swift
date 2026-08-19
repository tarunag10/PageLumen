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
}
