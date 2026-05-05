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
}
