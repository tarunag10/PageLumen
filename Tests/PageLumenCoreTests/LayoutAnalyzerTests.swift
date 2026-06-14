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

    // MARK: - Heading level detection (Phase 6.1)

    func testHeadingLevelDetectsNumberedSections() {
        let intro = TextBlock(pageNumber: 1, type: .paragraph, text: "1. Intro", bounds: BoundingBox(x: 70, y: 100, width: 200, height: 22), confidence: 0.95)
        let background = TextBlock(pageNumber: 1, type: .paragraph, text: "1.1 Background", bounds: BoundingBox(x: 70, y: 200, width: 220, height: 22), confidence: 0.95)
        let method = TextBlock(pageNumber: 1, type: .paragraph, text: "1.1.1 Method", bounds: BoundingBox(x: 70, y: 300, width: 220, height: 22), confidence: 0.95)
        let document = ReaderDocument(
            title: "Numbered",
            sourceType: .pdf,
            pages: [ReaderPage(pageNumber: 1, size: PageSize(width: 600, height: 800), blocks: [intro, background, method])]
        )

        let analyzed = LayoutAnalyzer().analyze(document: document)
        let levelsByTitle = Dictionary(uniqueKeysWithValues: analyzed.outline.map { ($0.title, $0.level) })

        XCTAssertEqual(levelsByTitle["1. Intro"], 1)
        XCTAssertEqual(levelsByTitle["1.1 Background"], 2)
        XCTAssertEqual(levelsByTitle["1.1.1 Method"], 3)
    }

    func testHeadingLevelDetectsAllCapsShortText() {
        let block = TextBlock(pageNumber: 1, type: .paragraph, text: "INTRODUCTION", bounds: BoundingBox(x: 70, y: 100, width: 200, height: 22), confidence: 0.95)
        let document = ReaderDocument(
            title: "AllCaps",
            sourceType: .pdf,
            pages: [ReaderPage(pageNumber: 1, size: PageSize(width: 600, height: 800), blocks: [block])]
        )

        let analyzed = LayoutAnalyzer().analyze(document: document)

        XCTAssertEqual(analyzed.outline.first?.title, "INTRODUCTION")
        XCTAssertEqual(analyzed.outline.first?.level, 1)
    }

    func testHeadingLevelDefaultsToLevel1ForShortBold() {
        // Height of 36 is enough to trip `isLikelyHeading` (>= 30) but stops
        // short of the L0 title threshold (>= 40 at top of page 1), so the
        // detector should fall back to L1.
        let block = TextBlock(pageNumber: 1, type: .paragraph, text: "Section Title", bounds: BoundingBox(x: 70, y: 100, width: 220, height: 36), confidence: 0.95)
        let document = ReaderDocument(
            title: "ShortBold",
            sourceType: .pdf,
            pages: [ReaderPage(pageNumber: 1, size: PageSize(width: 600, height: 800), blocks: [block])]
        )

        let analyzed = LayoutAnalyzer().analyze(document: document)

        XCTAssertEqual(analyzed.outline.first?.title, "Section Title")
        XCTAssertEqual(analyzed.outline.first?.level, 1)
    }

    // MARK: - 3-column and sidebar reading order (Phase 6.2)

    func testThreeColumnBlocksReadLeftToRight() {
        // Three columns centered at midX = 150 / 450 / 750 on a 900-wide page,
        // with two blocks each. We arrange the input order so the analyzer has
        // to reorder, not just return the input.
        let blocks = [
            TextBlock(pageNumber: 1, type: .paragraph, text: "col3-block1", bounds: BoundingBox(x: 650, y: 100, width: 200, height: 40), confidence: 0.95),
            TextBlock(pageNumber: 1, type: .paragraph, text: "col1-block2", bounds: BoundingBox(x: 50, y: 200, width: 200, height: 40), confidence: 0.95),
            TextBlock(pageNumber: 1, type: .paragraph, text: "col2-block1", bounds: BoundingBox(x: 350, y: 100, width: 200, height: 40), confidence: 0.95),
            TextBlock(pageNumber: 1, type: .paragraph, text: "col1-block1", bounds: BoundingBox(x: 50, y: 100, width: 200, height: 40), confidence: 0.95),
            TextBlock(pageNumber: 1, type: .paragraph, text: "col3-block2", bounds: BoundingBox(x: 650, y: 200, width: 200, height: 40), confidence: 0.95),
            TextBlock(pageNumber: 1, type: .paragraph, text: "col2-block2", bounds: BoundingBox(x: 350, y: 200, width: 200, height: 40), confidence: 0.95)
        ]
        let page = ReaderPage(pageNumber: 1, size: PageSize(width: 900, height: 1_200), blocks: blocks)

        let analyzed = LayoutAnalyzer().analyze(page: page)

        XCTAssertEqual(analyzed.layoutType, .multiColumn)
        XCTAssertEqual(
            analyzed.blocks.map(\.text),
            ["col1-block1", "col1-block2", "col2-block1", "col2-block2", "col3-block1", "col3-block2"]
        )
    }

    func testSidebarBlocksExcludedFromMainReadingOrder() {
        // A narrow, tall block hugging the right edge of the page is treated
        // as a sidebar: the layout flips to `.mixed` and the sidebar is read
        // after every main-body block.
        let main1 = TextBlock(pageNumber: 1, type: .paragraph, text: "Body paragraph one", bounds: BoundingBox(x: 100, y: 100, width: 600, height: 40), confidence: 0.95)
        let main2 = TextBlock(pageNumber: 1, type: .paragraph, text: "Body paragraph two", bounds: BoundingBox(x: 100, y: 200, width: 600, height: 40), confidence: 0.95)
        let sidebar = TextBlock(pageNumber: 1, type: .paragraph, text: "Sidebar marginalia", bounds: BoundingBox(x: 900, y: 80, width: 80, height: 1_100), confidence: 0.95)
        let page = ReaderPage(pageNumber: 1, size: PageSize(width: 1_000, height: 1_400), blocks: [sidebar, main1, main2])

        let analyzed = LayoutAnalyzer().analyze(page: page)

        XCTAssertEqual(analyzed.layoutType, .mixed)
        XCTAssertEqual(
            analyzed.blocks.map(\.text),
            ["Body paragraph one", "Body paragraph two", "Sidebar marginalia"]
        )
    }

    // MARK: - Footnote / caption detection (Phase 6.3)

    func testFootnoteBlocksAreMarked() {
        // Three body blocks plus a short footnote 1380/1400 = 0.986 down the
        // page (well past the 0.9 footnote threshold). The analyzer should
        // tag only the footnote with `.footer`.
        let body1 = TextBlock(pageNumber: 1, type: .paragraph, text: "First body paragraph.", bounds: BoundingBox(x: 80, y: 120, width: 600, height: 24), confidence: 0.95)
        let body2 = TextBlock(pageNumber: 1, type: .paragraph, text: "Second body paragraph.", bounds: BoundingBox(x: 80, y: 200, width: 600, height: 24), confidence: 0.95)
        let body3 = TextBlock(pageNumber: 1, type: .paragraph, text: "Third body paragraph.", bounds: BoundingBox(x: 80, y: 280, width: 600, height: 24), confidence: 0.95)
        let footnote = TextBlock(pageNumber: 1, type: .paragraph, text: "1 See attached references for sources.", bounds: BoundingBox(x: 80, y: 1_290, width: 600, height: 18), confidence: 0.95)
        let page = ReaderPage(pageNumber: 1, size: PageSize(width: 800, height: 1_400), blocks: [body1, body2, body3, footnote])

        let analyzed = LayoutAnalyzer().analyze(page: page)
        let footnoteBlock = analyzed.blocks.first { $0.text.hasPrefix("1 See attached") }

        XCTAssertEqual(footnoteBlock?.type, .footer)
        XCTAssertEqual(
            analyzed.blocks.filter { $0.text.contains("body paragraph") }.map(\.type),
            [.paragraph, .paragraph, .paragraph],
            "Body paragraphs should not be reclassified as footers"
        )
    }

    func testCaptionBlocksAreMarked() {
        // The figure block is 300 pt tall centered at y=350. The caption text
        // sits at y=420, height=20 → midY=430. |430 - 350| = 80 ≤ 0.3 * 300 (=90),
        // so the caption check fires and overrides the initial `.figure`
        // classification triggered by the word "Figure" in the caption text.
        let figureBlock = TextBlock(pageNumber: 1, type: .figure, text: "Chart legend showing trends.", bounds: BoundingBox(x: 100, y: 200, width: 400, height: 300), confidence: 0.92)
        let captionBlock = TextBlock(pageNumber: 1, type: .paragraph, text: "Figure 1: Sales trend.", bounds: BoundingBox(x: 100, y: 420, width: 380, height: 20), confidence: 0.95)
        let intro = TextBlock(pageNumber: 1, type: .paragraph, text: "Intro paragraph for context.", bounds: BoundingBox(x: 100, y: 100, width: 400, height: 22), confidence: 0.95)
        let page = ReaderPage(pageNumber: 1, size: PageSize(width: 700, height: 1_000), blocks: [intro, figureBlock, captionBlock])

        let analyzed = LayoutAnalyzer().analyze(page: page)
        let resolvedCaption = analyzed.blocks.first { $0.text == "Figure 1: Sales trend." }
        let resolvedFigure = analyzed.blocks.first { $0.text == "Chart legend showing trends." }

        XCTAssertEqual(resolvedCaption?.type, .caption)
        XCTAssertEqual(resolvedFigure?.type, .figure)
    }
}
