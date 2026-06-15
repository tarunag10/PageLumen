import PageLumenCore
import XCTest
@testable import PageLumen

@MainActor
final class ConfidenceChartViewTests: XCTestCase {
    func testChartHasAccessibilityChartDescriptor() {
        let document = SampleDataFactory.makeDemoDocument()
        let view = ConfidenceChartView(document: document)
        let descriptor = view.makeChartDescriptor()
        let title = descriptor.title ?? ""
        XCTAssertFalse(title.isEmpty)
    }

    func testChartHighlightsLowConfidencePages() {
        let page1 = ReaderPage(
            pageNumber: 1,
            size: PageSize(width: 612, height: 792),
            blocks: [
                TextBlock(pageNumber: 1, type: .paragraph, text: "High", bounds: BoundingBox(x: 0, y: 0, width: 100, height: 20), confidence: 0.95)
            ]
        )
        let page2 = ReaderPage(
            pageNumber: 2,
            size: PageSize(width: 612, height: 792),
            blocks: [
                TextBlock(pageNumber: 2, type: .paragraph, text: "Low", bounds: BoundingBox(x: 0, y: 0, width: 100, height: 20), confidence: 0.4)
            ]
        )
        let document = ReaderDocument(title: "Test", sourceType: .sample, pages: [page1, page2])
        let view = ConfidenceChartView(document: document)
        let descriptor = view.makeChartDescriptor()
        XCTAssertGreaterThan(descriptor.series.count, 0)
    }
}
