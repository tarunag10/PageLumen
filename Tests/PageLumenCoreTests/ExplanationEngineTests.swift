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
}
