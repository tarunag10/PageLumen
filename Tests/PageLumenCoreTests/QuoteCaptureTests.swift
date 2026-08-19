import XCTest
@testable import PageLumenCore

final class QuoteCaptureTests: XCTestCase {
    func testQuoteIncludesStablePageAndReadingOrderCitation() {
        let document = ReaderDocument(
            title: "Research notes",
            sourceType: .sample,
            pages: [ReaderPage(
                pageNumber: 4,
                size: PageSize(width: 100, height: 100),
                blocks: [TextBlock(
                    pageNumber: 4,
                    type: .paragraph,
                    text: "A quoted   paragraph\nwith wrapped lines.",
                    bounds: BoundingBox(x: 0, y: 0, width: 80, height: 20),
                    confidence: 0.95,
                    readingOrderIndex: 2
                )]
            )]
        )

        let quote = DocumentQuote.from(document: document, block: document.pages[0].blocks[0])

        XCTAssertEqual(quote.text, "A quoted paragraph with wrapped lines.")
        XCTAssertEqual(quote.citation, "Research notes, page 4, block 3")
        XCTAssertEqual(quote.accessibleExcerpt, "A quoted paragraph with wrapped lines.\n\n— Research notes, page 4, block 3")
    }

    func testQuoteIsCodableAndPreservesCitationInputs() throws {
        let quote = DocumentQuote(documentTitle: "Doc", pageNumber: 1, blockNumber: 1, text: "Text")
        let encoded = try JSONEncoder().encode(quote)
        let decoded = try JSONDecoder().decode(DocumentQuote.self, from: encoded)
        XCTAssertEqual(decoded, quote)
    }
}
