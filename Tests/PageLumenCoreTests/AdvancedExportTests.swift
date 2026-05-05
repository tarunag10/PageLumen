import XCTest
@testable import PageLumenCore

final class AdvancedExportTests: XCTestCase {
    func testCSVExportIncludesDetectedTables() {
        let document = SampleDataFactory.makeDemoDocument()

        let csv = ExportEngine().csv(for: document, options: .full)

        XCTAssertTrue(csv.contains("Page,Table,Row,Column,Value"))
        XCTAssertTrue(csv.contains("1,1,1,1,Item"))
        XCTAssertTrue(csv.contains("1,1,2,2,Ready"))
    }

    func testJSONExportIncludesBlocksTablesFiguresAndMetadata() throws {
        let document = SampleDataFactory.makeDemoDocument()

        let data = ExportEngine().data(for: document, format: .json, options: .full)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(object?["title"] as? String, "PageLumen Demo")
        XCTAssertNotNil(object?["pages"] as? [[String: Any]])
        XCTAssertNotNil(object?["summary"] as? String)
    }

    func testAccessibilityAuditFlagsMissingStructureAndReviewRisks() {
        let document = ReaderDocument(
            title: "Audit Me",
            sourceType: .sample,
            language: nil,
            pages: [
                ReaderPage(
                    pageNumber: 1,
                    size: PageSize(width: 612, height: 792),
                    blocks: [
                        TextBlock(
                            pageNumber: 1,
                            type: .heading,
                            text: "   ",
                            bounds: BoundingBox(x: 72, y: 80, width: 300, height: 24),
                            confidence: 0.95
                        ),
                        TextBlock(
                            pageNumber: 1,
                            type: .paragraph,
                            text: "Low confidence OCR text",
                            bounds: BoundingBox(x: 72, y: 120, width: 380, height: 18),
                            confidence: 0.42
                        ),
                        TextBlock(
                            pageNumber: 1,
                            type: .figure,
                            text: "",
                            bounds: BoundingBox(x: 72, y: 170, width: 300, height: 120),
                            confidence: 0.9
                        )
                    ],
                    tables: [
                        TableRegion(
                            pageNumber: 1,
                            bounds: BoundingBox(x: 72, y: 330, width: 300, height: 60),
                            rows: [["Only one row"]],
                            confidence: 0.88
                        )
                    ],
                    figures: [
                        FigureRegion(
                            pageNumber: 1,
                            bounds: BoundingBox(x: 72, y: 170, width: 300, height: 120),
                            chartType: .unknown,
                            visibleText: "",
                            description: "",
                            confidence: 0.9
                        )
                    ]
                )
            ]
        )

        let audit = AccessibilityAuditor().audit(document: document, options: .full)

        XCTAssertFalse(audit.isReadyForTaggedExport)
        XCTAssertTrue(audit.findings.contains { $0.kind == .missingLanguage })
        XCTAssertTrue(audit.findings.contains { $0.kind == .emptyHeading })
        XCTAssertTrue(audit.findings.contains { $0.kind == .lowConfidenceText })
        XCTAssertTrue(audit.findings.contains { $0.kind == .missingFigureDescription })
        XCTAssertTrue(audit.findings.contains { $0.kind == .tableNeedsHeaderReview })
    }

    func testTaggedHTMLExportIncludesAccessibilityLandmarksAndAuditMetadata() {
        let document = SampleDataFactory.makeDemoDocument()

        let html = ExportEngine().taggedHTML(for: document, options: .full)

        XCTAssertTrue(html.contains("<main id=\"content\">"))
        XCTAssertTrue(html.contains("data-pagelumen-export=\"tagged-html\""))
        XCTAssertTrue(html.contains("scope=\"col\""))
        XCTAssertTrue(html.contains("role=\"img\""))
        XCTAssertTrue(html.contains("aria-label=\""))
        XCTAssertTrue(html.contains("<section aria-labelledby=\"page-1-heading\" data-page=\"1\">"))
    }

    func testDemoDocumentStartsReadyForTaggedExport() {
        let document = SampleDataFactory.makeDemoDocument()

        let audit = AccessibilityAuditor().audit(document: document, options: .full)

        XCTAssertTrue(audit.isReadyForTaggedExport)
    }
}
