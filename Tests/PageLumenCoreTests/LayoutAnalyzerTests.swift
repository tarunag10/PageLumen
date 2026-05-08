import XCTest
@testable import PageLumenCore

final class LayoutAnalyzerTests: XCTestCase {
    func testTwoColumnBlocksReadLeftColumnBeforeRightColumn() {
        let page = ReaderPage(
            pageNumber: 1,
            size: PageSize(width: 1_000, height: 1_400),
            blocks: [
                TextBlock(pageNumber: 1, type: .paragraph, text: "Right top", bounds: BoundingBox(x: 620, y: 140, width: 260, height: 40), confidence: 0.91),
                TextBlock(pageNumber: 1, type: .paragraph, text: "Left bottom", bounds: BoundingBox(x: 100, y: 280, width: 260, height: 40), confidence: 0.94),
                TextBlock(pageNumber: 1, type: .paragraph, text: "Left top", bounds: BoundingBox(x: 100, y: 140, width: 260, height: 40), confidence: 0.96),
                TextBlock(pageNumber: 1, type: .paragraph, text: "Right bottom", bounds: BoundingBox(x: 620, y: 280, width: 260, height: 40), confidence: 0.89)
            ]
        )

        let analyzed = LayoutAnalyzer().analyze(page: page)

        XCTAssertEqual(analyzed.layoutType, .multiColumn)
        XCTAssertEqual(analyzed.blocks.map(\.text), ["Left top", "Left bottom", "Right top", "Right bottom"])
        XCTAssertEqual(analyzed.blocks.map(\.readingOrderIndex), [0, 1, 2, 3])
    }

    func testLikelyHeadingsArePromotedAndOutlineCreated() {
        let document = ReaderDocument(
            title: "Lecture Scan",
            sourceType: .pdf,
            pages: [
                ReaderPage(
                    pageNumber: 1,
                    size: PageSize(width: 900, height: 1_200),
                    blocks: [
                        TextBlock(pageNumber: 1, type: .paragraph, text: "INTRODUCTION", bounds: BoundingBox(x: 80, y: 60, width: 400, height: 36), confidence: 0.97),
                        TextBlock(pageNumber: 1, type: .paragraph, text: "This page explains the topic.", bounds: BoundingBox(x: 80, y: 130, width: 500, height: 40), confidence: 0.93)
                    ]
                )
            ]
        )

        let analyzed = LayoutAnalyzer().analyze(document: document)

        XCTAssertEqual(analyzed.outline.map(\.title), ["INTRODUCTION"])
        XCTAssertEqual(analyzed.pages[0].blocks[0].type, .heading)
    }

    func testAdjacentOCRLinesAreMergedIntoReadableParagraphs() {
        let page = ReaderPage(
            pageNumber: 1,
            size: PageSize(width: 600, height: 800),
            blocks: [
                TextBlock(
                    pageNumber: 1,
                    type: .paragraph,
                    text: "This is the first OCR line",
                    bounds: BoundingBox(x: 72, y: 120, width: 320, height: 18),
                    confidence: 0.91,
                    metadata: ["source": "vision-ocr"]
                ),
                TextBlock(
                    pageNumber: 1,
                    type: .paragraph,
                    text: "that belongs to the same paragraph.",
                    bounds: BoundingBox(x: 72, y: 143, width: 340, height: 18),
                    confidence: 0.89,
                    metadata: ["source": "vision-ocr"]
                ),
                TextBlock(
                    pageNumber: 1,
                    type: .paragraph,
                    text: "A separate paragraph starts here.",
                    bounds: BoundingBox(x: 72, y: 205, width: 330, height: 18),
                    confidence: 0.94,
                    metadata: ["source": "vision-ocr"]
                )
            ]
        )

        let analyzed = LayoutAnalyzer().analyze(page: page)

        XCTAssertEqual(analyzed.blocks.count, 2)
        XCTAssertEqual(analyzed.blocks[0].text, "This is the first OCR line that belongs to the same paragraph.")
        XCTAssertEqual(analyzed.blocks[0].metadata["source"], "vision-ocr")
        XCTAssertEqual(analyzed.blocks[0].metadata["mergedLineCount"], "2")
    }

    func testReceiptProfilePromotesKeyValueRowsToTable() {
        let page = ReaderPage(
            pageNumber: 1,
            size: PageSize(width: 420, height: 720),
            blocks: [
                TextBlock(pageNumber: 1, type: .paragraph, text: "Subtotal: $18.50", bounds: BoundingBox(x: 32, y: 80, width: 180, height: 20), confidence: 0.96),
                TextBlock(pageNumber: 1, type: .paragraph, text: "Tax: $1.48", bounds: BoundingBox(x: 32, y: 112, width: 180, height: 20), confidence: 0.95),
                TextBlock(pageNumber: 1, type: .paragraph, text: "Total: $19.98", bounds: BoundingBox(x: 32, y: 144, width: 180, height: 20), confidence: 0.98)
            ]
        )

        let analyzed = LayoutAnalyzer(profile: .receipts).analyze(document: ReaderDocument(title: "Receipt", sourceType: .image, pages: [page]))

        XCTAssertEqual(analyzed.pages[0].layoutType, .form)
        XCTAssertEqual(analyzed.pages[0].blocks.map(\.type), [.table])
        XCTAssertEqual(analyzed.pages[0].tables.first?.rows, [["Subtotal", "$18.50"], ["Tax", "$1.48"], ["Total", "$19.98"]])
    }

    func testAcademicProfilePromotesKnownSectionTitlesToHeadings() {
        let page = ReaderPage(
            pageNumber: 1,
            size: PageSize(width: 640, height: 900),
            blocks: [
                TextBlock(pageNumber: 1, type: .paragraph, text: "References", bounds: BoundingBox(x: 70, y: 70, width: 160, height: 22), confidence: 0.97),
                TextBlock(pageNumber: 1, type: .paragraph, text: "Smith, A. Accessible documents.", bounds: BoundingBox(x: 70, y: 120, width: 360, height: 22), confidence: 0.92)
            ]
        )

        let analyzed = LayoutAnalyzer(profile: .academic).analyze(document: ReaderDocument(title: "Paper", sourceType: .pdf, pages: [page]))

        XCTAssertEqual(analyzed.pages[0].blocks.first?.type, .heading)
        XCTAssertEqual(analyzed.outline.first?.title, "References")
    }

    func testSlidesProfileClassifiesSparseLargeTextPageAsSlide() {
        let page = ReaderPage(
            pageNumber: 1,
            size: PageSize(width: 1_280, height: 720),
            blocks: [
                TextBlock(pageNumber: 1, type: .paragraph, text: "Quarterly accessibility review", bounds: BoundingBox(x: 120, y: 80, width: 720, height: 42), confidence: 0.97),
                TextBlock(pageNumber: 1, type: .paragraph, text: "Three findings need review before launch", bounds: BoundingBox(x: 140, y: 180, width: 780, height: 34), confidence: 0.94),
                TextBlock(pageNumber: 1, type: .paragraph, text: "Chart shows export readiness improving", bounds: BoundingBox(x: 140, y: 300, width: 620, height: 30), confidence: 0.9)
            ]
        )

        let analyzed = LayoutAnalyzer(profile: .slides).analyze(document: ReaderDocument(title: "Deck", sourceType: .image, pages: [page]))

        XCTAssertEqual(analyzed.pages[0].layoutType, .slide)
        XCTAssertEqual(analyzed.pages[0].blocks.first?.type, .heading)
        XCTAssertEqual(analyzed.pages[0].figures.first?.chartType, .unknown)
    }
}
