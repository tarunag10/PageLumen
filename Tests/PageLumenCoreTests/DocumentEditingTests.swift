import XCTest
@testable import PageLumenCore

final class DocumentEditingTests: XCTestCase {

    func testReviewSelectionPayloadRoundTripsWithoutSourceText() throws {
        let documentID = UUID()
        let blockID = UUID()
        let payload = ReviewSelectionPayload(
            documentID: documentID,
            pageNumber: 4,
            blockID: blockID,
            issueID: "lowConfidence-4-\(blockID.uuidString)"
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ReviewSelectionPayload.self, from: data)

        XCTAssertEqual(decoded, payload)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("text"))
    }

    func testPageOnlyReviewSelectionPayloadCanOmitDocumentAndBlock() throws {
        let payload = ReviewSelectionPayload(pageNumber: 2)
        let decoded = try JSONDecoder().decode(
            ReviewSelectionPayload.self,
            from: JSONEncoder().encode(payload)
        )

        XCTAssertNil(decoded.documentID)
        XCTAssertNil(decoded.blockID)
        XCTAssertNil(decoded.issueID)
        XCTAssertEqual(decoded.pageNumber, 2)
    }
    func testReviewPresetsAdjustConfidenceThresholdsWithoutChangingSource() {
        let block = TextBlock(pageNumber: 1, type: .paragraph, text: "Borderline", bounds: BoundingBox(x: 0, y: 0, width: 100, height: 20), confidence: 0.8)
        let document = ReaderDocument(title: "Preset", sourceType: .sample, pages: [
            ReaderPage(pageNumber: 1, size: PageSize(width: 400, height: 600), blocks: [block])
        ])

        XCTAssertTrue(DocumentEditing.reviewIssues(for: document, preset: .general).isEmpty)
        XCTAssertEqual(DocumentEditing.reviewIssues(for: document, preset: .legal).first?.kind, .lowConfidence)
        XCTAssertEqual(document.pages[0].blocks[0].text, "Borderline")
    }

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

    func testReviewFindingsNormalizeSeverityAndRemainUnresolved() {
        var document = SampleDataFactory.makeDemoDocument()
        document.pages[0].warning = "The page may be skewed."

        let findings = DocumentEditing.reviewFindings(for: document)

        XCTAssertFalse(findings.isEmpty)
        XCTAssertTrue(findings.contains { $0.kind == .pageWarning && $0.severity == .blocker })
        XCTAssertTrue(findings.allSatisfy { !$0.isResolved })
        XCTAssertTrue(findings.allSatisfy { !$0.id.isEmpty })
    }

    func testReviewFindingsCarryTypedSourceProvenanceWithoutTextDuplication() {
        var document = SampleDataFactory.makeDemoDocument()
        for pageIndex in document.pages.indices {
            for blockIndex in document.pages[pageIndex].blocks.indices {
                document.pages[pageIndex].blocks[blockIndex].metadata["source"] = BlockSource.visionOCR.rawValue
            }
        }

        guard let finding = DocumentEditing.reviewFindings(for: document).first(where: { $0.blockID != nil }),
              let sourceBlock = document.allBlocks.first(where: { $0.id == finding.blockID }) else {
            return XCTFail("Expected a block-backed review finding")
        }

        XCTAssertEqual(finding.provenance?.source, .visionOCR)
        XCTAssertEqual(finding.provenance?.pageNumber, 1)
        XCTAssertEqual(finding.provenance?.parentBlockID, finding.blockID)
        XCTAssertEqual(finding.provenance?.bounds, sourceBlock.bounds)
        XCTAssertFalse(String(describing: finding.provenance).contains(sourceBlock.text))
    }

    func testReviewFindingsUseDeterministicRiskCategoriesAndPriorityOrder() {
        let unreadable = ReaderPage(
            pageNumber: 1,
            size: PageSize(width: 400, height: 600),
            ocrStatus: .failed,
            blocks: []
        )
        let unknown = TextBlock(pageNumber: 2, type: .unknown, text: "Unclassified", bounds: BoundingBox(x: 0, y: 0, width: 100, height: 20), confidence: 0.95)
        let low = TextBlock(pageNumber: 3, type: .paragraph, text: "Low confidence", bounds: BoundingBox(x: 0, y: 0, width: 100, height: 20), confidence: 0.2)
        let conflicting = TextBlock(
            pageNumber: 4,
            type: .paragraph,
            text: "Conflicting source",
            bounds: BoundingBox(x: 0, y: 0, width: 100, height: 20),
            confidence: 0.95,
            metadata: ["source": BlockSource.embeddedPDF.rawValue],
            provenance: BlockProvenance(source: .visionOCR, pageNumber: 4)
        )
        let tableBounds = BoundingBox(x: 0, y: 0, width: 100, height: 40)
        let tableBlock = TextBlock(pageNumber: 5, type: .table, text: "A | B", bounds: tableBounds, confidence: 0.95)
        let figureBounds = BoundingBox(x: 0, y: 50, width: 100, height: 40)
        let figureBlock = TextBlock(pageNumber: 6, type: .figure, text: "Chart", bounds: figureBounds, confidence: 0.95)
        let ai = TextBlock(
            pageNumber: 7,
            type: .paragraph,
            text: "Generated draft",
            bounds: BoundingBox(x: 0, y: 0, width: 100, height: 20),
            confidence: 0.95,
            provenance: BlockProvenance(source: .appleIntelligence, pageNumber: 7)
        )
        let document = ReaderDocument(title: "Priority", sourceType: .sample, pages: [
            unreadable,
            ReaderPage(pageNumber: 2, size: PageSize(width: 400, height: 600), blocks: [unknown]),
            ReaderPage(pageNumber: 3, size: PageSize(width: 400, height: 600), blocks: [low]),
            ReaderPage(pageNumber: 4, size: PageSize(width: 400, height: 600), blocks: [conflicting]),
            ReaderPage(pageNumber: 5, size: PageSize(width: 400, height: 600), blocks: [tableBlock], tables: [TableRegion(pageNumber: 5, bounds: tableBounds, rows: [["A", "B"], ["1", "2"]], confidence: 0.95)]),
            ReaderPage(pageNumber: 6, size: PageSize(width: 400, height: 600), blocks: [figureBlock], figures: [FigureRegion(pageNumber: 6, bounds: figureBounds, chartType: .bar, visibleText: "Chart", description: "", confidence: 0.95)]),
            ReaderPage(pageNumber: 7, size: PageSize(width: 400, height: 600), blocks: [ai])
        ])

        let findings = DocumentEditing.reviewFindings(for: document)

        XCTAssertEqual(findings.map(\.category), [
            .unreadablePage,
            .missingStructure,
            .lowConfidence,
            .conflictingExtractionSources,
            .unresolvedTableHeaders,
            .missingImageDescription,
            .unreviewedAIContribution
        ])
        XCTAssertEqual(findings.map(\.category.priority), Array(0...6))
        XCTAssertEqual(findings.last?.provenance?.source, .appleIntelligence)
        XCTAssertTrue(findings.allSatisfy { !$0.isResolved })
    }

    func testReviewFindingCategoryDecodesForLegacyPayloadWithoutCategory() throws {
        let finding = ReviewFinding(id: "low", kind: .lowConfidence, severity: .warning, pageNumber: 1, title: "Low", detail: "Review")
        let data = try JSONEncoder().encode(finding)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "category")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(ReviewFinding.self, from: legacyData)

        XCTAssertEqual(decoded.category, .lowConfidence)
    }

    func testReviewDecisionPersistsAcceptedAndRejectedStates() {
        let block = TextBlock(pageNumber: 1, type: .unknown, text: "Keep source", bounds: BoundingBox(x: 0, y: 0, width: 100, height: 20), confidence: 0.4)
        var document = ReaderDocument(title: "Decisions", sourceType: .sample, pages: [
            ReaderPage(pageNumber: 1, size: PageSize(width: 400, height: 600), blocks: [block])
        ])

        XCTAssertEqual(DocumentEditing.reviewDecision(document.pages[0].blocks[0]), .unreviewed)
        DocumentEditing.setReviewDecision(id: block.id, decision: .rejected, in: &document)
        XCTAssertEqual(DocumentEditing.reviewDecision(document.pages[0].blocks[0]), .rejected)
        XCTAssertFalse(DocumentEditing.isReviewed(document.pages[0].blocks[0]))
        XCTAssertTrue(DocumentEditing.reviewIssues(for: document).isEmpty)

        DocumentEditing.setReviewDecision(id: block.id, decision: .accepted, in: &document)
        XCTAssertEqual(DocumentEditing.reviewDecision(document.pages[0].blocks[0]), .accepted)
        XCTAssertTrue(DocumentEditing.isReviewed(document.pages[0].blocks[0]))

        DocumentEditing.setReviewDecision(id: block.id, decision: .unreviewed, in: &document)
        XCTAssertEqual(DocumentEditing.reviewDecision(document.pages[0].blocks[0]), .unreviewed)
        XCTAssertEqual(DocumentEditing.reviewIssues(for: document).count, 1)
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
