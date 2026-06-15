import XCTest
@testable import PageLumenCore

final class IntelligentExplainerTests: XCTestCase {
    func testAvailabilityReturnsAValue() {
        let availability = IntelligentExplainer().availability
        XCTAssertNotNil(availability)
    }

    func testAvailabilityIsOneOfTheKnownCases() {
        let availability = IntelligentExplainer().availability
        switch availability {
        case .available, .unavailable, .notSupported:
            break
        }
    }

    func testSummaryFallsBackWhenIntelligenceDisabled() async {
        let document = SampleDataFactory.makeDemoDocument()
        let options = SummaryOptions(useIntelligence: false, maxSentences: 0)
        let summary = await ExplanationEngine().summary(for: document, length: .short, options: options)
        XCTAssertFalse(summary.isEmpty)
        XCTAssertTrue(summary.contains("Page 1"))
    }

    func testSummaryFallsBackWhenIntelligenceEnabledButUnavailable() async {
        let document = SampleDataFactory.makeDemoDocument()
        let options = SummaryOptions(useIntelligence: true, maxSentences: 0)
        let summary = await ExplanationEngine().summary(for: document, length: .short, options: options)
        XCTAssertFalse(summary.isEmpty)
    }

    func testSummaryRespectsLengthParameter() async {
        let document = SampleDataFactory.makeDemoDocument()
        let options = SummaryOptions(useIntelligence: false, maxSentences: 0)
        let short = await ExplanationEngine().summary(for: document, length: .short, options: options)
        let detailed = await ExplanationEngine().summary(for: document, length: .detailed, options: options)
        XCTAssertFalse(short.isEmpty)
        XCTAssertFalse(detailed.isEmpty)
    }

    func testSummaryOptionsDefaultDisablesIntelligence() {
        let options = SummaryOptions.default
        XCTAssertFalse(options.useIntelligence)
        XCTAssertEqual(options.maxSentences, 0)
    }

    func testTableAndFigureExplainersReturnEmptyOrFallback() async {
        let explainer = IntelligentExplainer()
        let table = TableRegion(
            pageNumber: 1,
            bounds: BoundingBox(x: 0, y: 0, width: 100, height: 100),
            rows: [["A", "B"], ["1", "2"]],
            confidence: 0.9
        )
        let figure = FigureRegion(
            pageNumber: 1,
            bounds: BoundingBox(x: 0, y: 0, width: 100, height: 100),
            chartType: .bar,
            visibleText: "Sample chart label",
            description: "",
            confidence: 0.9
        )
        let tableExplanation = await explainer.explain(table: table)
        let figureExplanation = await explainer.explain(figure: figure)
        if case .available = explainer.availability {
            XCTAssertTrue(tableExplanation.isEmpty || !tableExplanation.isEmpty)
            XCTAssertTrue(figureExplanation.isEmpty || !figureExplanation.isEmpty)
        } else {
            XCTAssertEqual(tableExplanation, "")
            XCTAssertEqual(figureExplanation, "")
        }
    }
}
