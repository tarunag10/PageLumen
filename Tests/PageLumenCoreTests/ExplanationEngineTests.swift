import XCTest
@testable import PageLumenCore

final class ExplanationEngineTests: XCTestCase {
    func testAudioSummaryUsesExtractedContentAndPageReferences() {
        let document = SampleDataFactory.makeDemoDocument()

        let summary = ExplanationEngine().summary(for: document, length: .short)

        XCTAssertTrue(summary.contains("Page 1"))
        XCTAssertTrue(summary.contains("PageLumen turns inaccessible visual documents"))
        XCTAssertFalse(summary.contains("cloud"))
    }

    func testTableExplanationIsGroundedAndUncertaintyAware() {
        let table = TableRegion(
            pageNumber: 2,
            bounds: BoundingBox(x: 40, y: 40, width: 300, height: 120),
            rows: [["Metric", "Value"], ["Confidence", "92%"]],
            confidence: 0.68
        )

        let explanation = ExplanationEngine().explain(table: table)

        XCTAssertTrue(explanation.contains("2 columns"))
        XCTAssertTrue(explanation.contains("Confidence"))
        XCTAssertTrue(explanation.contains("review"))
    }

    func testBetterSummaryShortPicksHeadingAndABody() {
        let document = SampleDataFactory.makeDemoDocument()

        let summary = ExplanationEngine().betterSummary(for: document, length: .short)

        XCTAssertTrue(summary.contains("IMPORT FLOW"), "Short summary should anchor on the first heading")
        XCTAssertTrue(summary.contains("PageLumen turns inaccessible visual documents"))
        XCTAssertFalse(summary.contains("###"))
    }

    func testBetterSummaryMediumAnchorsMultipleHeadings() {
        let document = makeMultiSectionDocument()

        let summary = ExplanationEngine().betterSummary(for: document, length: .medium)

        XCTAssertTrue(summary.contains("Section: Introduction"))
        XCTAssertTrue(summary.contains("Section: Findings"))
        XCTAssertTrue(summary.contains("Section: Appendix"))
    }

    func testBetterSummaryMediumRespectsHeadingBudget() {
        let document = makeDocumentWithManyHeadings()

        let summary = ExplanationEngine().betterSummary(for: document, length: .medium)

        XCTAssertTrue(summary.contains("Section: Heading 1"))
        XCTAssertTrue(summary.contains("Section: Heading 3"))
        XCTAssertFalse(summary.contains("Section: Heading 5"))
    }

    func testBetterSummaryDetailedIncludesAllHeadings() {
        let document = makeMultiSectionDocument()

        let summary = ExplanationEngine().betterSummary(for: document, length: .detailed)

        XCTAssertTrue(summary.contains("Section: Introduction"))
        XCTAssertTrue(summary.contains("Section: Findings"))
        XCTAssertTrue(summary.contains("Section: Appendix"))
        XCTAssertTrue(summary.contains("Final closing paragraph for the appendix."))
    }

    func testBetterSummaryRewritesVisibleOnlyReferences() {
        let document = makeDocumentWithVisibleReferences()

        let summary = ExplanationEngine().betterSummary(for: document, length: .detailed)

        XCTAssertFalse(summary.contains("see Figure 3"))
        XCTAssertFalse(summary.contains("see Table 2"))
        XCTAssertFalse(summary.contains("on page 4"))
        XCTAssertFalse(summary.contains("see section 1.2"))
        XCTAssertTrue(summary.contains("a figure on this page"))
        XCTAssertTrue(summary.contains("a table on this page"))
        XCTAssertTrue(summary.contains("on a nearby page"))
        XCTAssertTrue(summary.contains("in another section"))
    }

    private func makeMultiSectionDocument() -> ReaderDocument {
        let introHeading = TextBlock(pageNumber: 1, type: .heading, text: "Introduction", bounds: BoundingBox(x: 0, y: 0, width: 100, height: 20), confidence: 0.95, readingOrderIndex: 0)
        let introBody = TextBlock(pageNumber: 1, type: .paragraph, text: "This document summarizes the audit findings.", bounds: BoundingBox(x: 0, y: 40, width: 100, height: 20), confidence: 0.95, readingOrderIndex: 1)
        let findingsHeading = TextBlock(pageNumber: 2, type: .heading, text: "Findings", bounds: BoundingBox(x: 0, y: 0, width: 100, height: 20), confidence: 0.95, readingOrderIndex: 0)
        let findingsBody = TextBlock(pageNumber: 2, type: .paragraph, text: "Three sections need attention before launch.", bounds: BoundingBox(x: 0, y: 40, width: 100, height: 20), confidence: 0.95, readingOrderIndex: 1)
        let appendixHeading = TextBlock(pageNumber: 3, type: .heading, text: "Appendix", bounds: BoundingBox(x: 0, y: 0, width: 100, height: 20), confidence: 0.95, readingOrderIndex: 0)
        let appendixBody = TextBlock(pageNumber: 3, type: .paragraph, text: "Final closing paragraph for the appendix.", bounds: BoundingBox(x: 0, y: 40, width: 100, height: 20), confidence: 0.95, readingOrderIndex: 1)

        return ReaderDocument(
            title: "Audit",
            sourceType: .sample,
            pages: [
                ReaderPage(pageNumber: 1, size: PageSize(width: 400, height: 600), blocks: [introHeading, introBody]),
                ReaderPage(pageNumber: 2, size: PageSize(width: 400, height: 600), blocks: [findingsHeading, findingsBody]),
                ReaderPage(pageNumber: 3, size: PageSize(width: 400, height: 600), blocks: [appendixHeading, appendixBody])
            ]
        )
    }

    private func makeDocumentWithVisibleReferences() -> ReaderDocument {
        let heading = TextBlock(pageNumber: 1, type: .heading, text: "References", bounds: BoundingBox(x: 0, y: 0, width: 100, height: 20), confidence: 0.95, readingOrderIndex: 0)
        let body = TextBlock(pageNumber: 1, type: .paragraph, text: "see Figure 3 for the trend, refer to Table 2 for the totals, and on page 4 we compare with the prior year. See section 1.2 for the methodology.",
                              bounds: BoundingBox(x: 0, y: 40, width: 100, height: 80), confidence: 0.95, readingOrderIndex: 1)
        return ReaderDocument(
            title: "Visible Refs",
            sourceType: .sample,
            pages: [ReaderPage(pageNumber: 1, size: PageSize(width: 400, height: 600), blocks: [heading, body])]
        )
    }

    private func makeDocumentWithManyHeadings() -> ReaderDocument {
        var pages: [ReaderPage] = []
        for index in 1...6 {
            let heading = TextBlock(pageNumber: index, type: .heading, text: "Heading \(index)", bounds: BoundingBox(x: 0, y: 0, width: 100, height: 20), confidence: 0.95, readingOrderIndex: 0)
            let body = TextBlock(pageNumber: index, type: .paragraph, text: "Body \(index).", bounds: BoundingBox(x: 0, y: 40, width: 100, height: 20), confidence: 0.95, readingOrderIndex: 1)
            pages.append(ReaderPage(pageNumber: index, size: PageSize(width: 400, height: 600), blocks: [heading, body]))
        }
        return ReaderDocument(title: "Many Headings", sourceType: .sample, pages: pages)
    }
}
