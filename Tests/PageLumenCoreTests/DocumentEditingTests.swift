import XCTest
@testable import PageLumenCore

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

    func testMarkBlockReviewedStoresReviewMetadata() {
        let block = TextBlock(pageNumber: 1, type: .paragraph, text: "Needs checking", bounds: BoundingBox(x: 10, y: 80, width: 300, height: 20), confidence: 0.6)
        var document = ReaderDocument(title: "Review", sourceType: .sample, pages: [
            ReaderPage(pageNumber: 1, size: PageSize(width: 400, height: 600), blocks: [block])
        ])

        DocumentEditing.setBlockReviewed(id: block.id, isReviewed: true, in: &document)

        XCTAssertEqual(document.pages[0].blocks[0].metadata["reviewStatus"], "reviewed")
    }

    func testMarkPageReviewedStoresReviewMetadataOnEveryBlock() {
        let first = TextBlock(pageNumber: 1, type: .paragraph, text: "First", bounds: BoundingBox(x: 10, y: 80, width: 300, height: 20), confidence: 0.9)
        let second = TextBlock(pageNumber: 1, type: .table, text: "A\tB", bounds: BoundingBox(x: 10, y: 120, width: 300, height: 20), confidence: 0.8)
        var document = ReaderDocument(title: "Review page", sourceType: .sample, pages: [
            ReaderPage(pageNumber: 1, size: PageSize(width: 400, height: 600), blocks: [first, second])
        ])

        DocumentEditing.setPageReviewed(pageNumber: 1, isReviewed: true, in: &document)

        XCTAssertEqual(document.pages[0].blocks.map { $0.metadata["reviewStatus"] }, ["reviewed", "reviewed"])
    }

    func testChangeBlockTypeUpdatesOutlineForHeadings() {
        let block = TextBlock(pageNumber: 1, type: .paragraph, text: "Methods", bounds: BoundingBox(x: 10, y: 80, width: 300, height: 20), confidence: 0.9)
        var document = ReaderDocument(title: "Types", sourceType: .sample, pages: [
            ReaderPage(pageNumber: 1, size: PageSize(width: 400, height: 600), blocks: [block])
        ])

        DocumentEditing.changeBlockType(id: block.id, to: .heading, in: &document)

        XCTAssertEqual(document.pages[0].blocks[0].type, .heading)
        XCTAssertEqual(document.outline.map(\.title), ["Methods"])
    }

    func testReviewIssuesIncludeLowConfidenceUnknownAndUnreviewedBlocks() {
        var reviewedLowConfidence = TextBlock(pageNumber: 1, type: .paragraph, text: "Reviewed", bounds: BoundingBox(x: 10, y: 80, width: 300, height: 20), confidence: 0.55)
        reviewedLowConfidence.metadata["reviewStatus"] = "reviewed"
        let unknown = TextBlock(pageNumber: 1, type: .unknown, text: "Unknown", bounds: BoundingBox(x: 10, y: 120, width: 300, height: 20), confidence: 0.9)
        let lowConfidence = TextBlock(pageNumber: 2, type: .paragraph, text: "Needs review", bounds: BoundingBox(x: 10, y: 80, width: 300, height: 20), confidence: 0.42)
        let document = ReaderDocument(title: "Issues", sourceType: .sample, pages: [
            ReaderPage(pageNumber: 1, size: PageSize(width: 400, height: 600), blocks: [reviewedLowConfidence, unknown], warning: "Check reading order"),
            ReaderPage(pageNumber: 2, size: PageSize(width: 400, height: 600), blocks: [lowConfidence])
        ])

        let issues = DocumentEditing.reviewIssues(for: document)

        XCTAssertEqual(issues.map(\.kind), [.pageWarning, .unknownBlockType, .lowConfidence])
        XCTAssertEqual(DocumentEditing.reviewProgress(for: document).reviewedBlocks, 1)
        XCTAssertEqual(DocumentEditing.reviewProgress(for: document).totalBlocks, 3)
    }

    func testExportPreviewUsesSelectedFormatAndOptions() {
        let block = TextBlock(pageNumber: 1, type: .heading, text: "Introduction", bounds: BoundingBox(x: 10, y: 80, width: 300, height: 20), confidence: 0.9)
        let document = ReaderDocument(title: "Preview", sourceType: .sample, pages: [
            ReaderPage(pageNumber: 1, size: PageSize(width: 400, height: 600), blocks: [block])
        ])

        let preview = DocumentEditing.exportPreview(for: document, format: .markdown, options: .full, maxCharacters: 40)

        XCTAssertTrue(preview.contains("# Introduction"))
        XCTAssertLessThanOrEqual(preview.count, 40)
    }

    private func makePage(number: Int, body: String) -> ReaderPage {
        ReaderPage(pageNumber: number, size: PageSize(width: 400, height: 600), blocks: [
            TextBlock(pageNumber: number, type: .paragraph, text: "Course Packet", bounds: BoundingBox(x: 20, y: 10, width: 220, height: 20), confidence: 0.95),
            TextBlock(pageNumber: number, type: .paragraph, text: body, bounds: BoundingBox(x: 20, y: 120, width: 260, height: 20), confidence: 0.95),
            TextBlock(pageNumber: number, type: .paragraph, text: "Confidential", bounds: BoundingBox(x: 20, y: 560, width: 180, height: 20), confidence: 0.95)
        ])
    }
}
