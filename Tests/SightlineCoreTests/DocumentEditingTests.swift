import XCTest
@testable import SightlineCore

final class DocumentEditingTests: XCTestCase {
    func testMoveBlockChangesReadingOrderWithinPage() {
        let first = TextBlock(pageNumber: 1, type: .paragraph, text: "First", bounds: BoundingBox(x: 20, y: 20, width: 100, height: 20), confidence: 0.9, readingOrderIndex: 0)
        let second = TextBlock(pageNumber: 1, type: .paragraph, text: "Second", bounds: BoundingBox(x: 20, y: 60, width: 100, height: 20), confidence: 0.9, readingOrderIndex: 1)
        let third = TextBlock(pageNumber: 1, type: .paragraph, text: "Third", bounds: BoundingBox(x: 20, y: 100, width: 100, height: 20), confidence: 0.9, readingOrderIndex: 2)
        var document = ReaderDocument(title: "Order", sourceType: .sample, pages: [
            ReaderPage(pageNumber: 1, size: PageSize(width: 400, height: 600), blocks: [first, second, third])
        ])

        DocumentEditing.moveBlock(id: third.id, direction: .up, in: &document)

        XCTAssertEqual(document.pages[0].blocks.map(\.text), ["First", "Third", "Second"])
        XCTAssertEqual(document.pages[0].blocks.map(\.readingOrderIndex), [0, 1, 2])
    }

    func testRepeatedHeadersAndFootersAreMarkedAcrossPages() {
        let document = ReaderDocument(title: "Headers", sourceType: .sample, pages: [
            makePage(number: 1, body: "Page one body"),
            makePage(number: 2, body: "Page two body")
        ])

        let analyzed = LayoutAnalyzer().analyze(document: document)

        XCTAssertEqual(analyzed.pages[0].blocks[0].type, .header)
        XCTAssertEqual(analyzed.pages[1].blocks[0].type, .header)
        XCTAssertEqual(analyzed.pages[0].blocks.last?.type, .footer)
        XCTAssertEqual(analyzed.pages[1].blocks.last?.type, .footer)
    }

    func testExportableBlocksCanExcludeHeadersAndFooters() {
        var header = TextBlock(pageNumber: 1, type: .header, text: "Course Packet", bounds: BoundingBox(x: 10, y: 10, width: 200, height: 20), confidence: 0.9)
        header.readingOrderIndex = 0
        var body = TextBlock(pageNumber: 1, type: .paragraph, text: "Keep this paragraph", bounds: BoundingBox(x: 10, y: 80, width: 300, height: 20), confidence: 0.9)
        body.readingOrderIndex = 1
        var footer = TextBlock(pageNumber: 1, type: .footer, text: "Page 1", bounds: BoundingBox(x: 10, y: 560, width: 100, height: 20), confidence: 0.9)
        footer.readingOrderIndex = 2
        let document = ReaderDocument(title: "Filtered", sourceType: .sample, pages: [
            ReaderPage(pageNumber: 1, size: PageSize(width: 400, height: 600), blocks: [header, body, footer])
        ])

        let text = DocumentEditing.fullText(for: document, includeHeadersAndFooters: false)

        XCTAssertEqual(text, "Keep this paragraph")
    }

    private func makePage(number: Int, body: String) -> ReaderPage {
        ReaderPage(pageNumber: number, size: PageSize(width: 400, height: 600), blocks: [
            TextBlock(pageNumber: number, type: .paragraph, text: "Course Packet", bounds: BoundingBox(x: 20, y: 10, width: 220, height: 20), confidence: 0.95),
            TextBlock(pageNumber: number, type: .paragraph, text: body, bounds: BoundingBox(x: 20, y: 120, width: 260, height: 20), confidence: 0.95),
            TextBlock(pageNumber: number, type: .paragraph, text: "Confidential", bounds: BoundingBox(x: 20, y: 560, width: 180, height: 20), confidence: 0.95)
        ])
    }
}
