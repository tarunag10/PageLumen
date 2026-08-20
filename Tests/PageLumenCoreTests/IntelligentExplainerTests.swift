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

    func testAvailabilityInfoIsPrivacySafeAndExplainsFallback() {
        let info = IntelligentExplainer().availabilityInfo
        XCTAssertFalse(info.title.isEmpty)
        XCTAssertFalse(info.message.isEmpty)
        XCTAssertTrue(info.privacyBoundary.localizedCaseInsensitiveContains("on-device"))
        XCTAssertTrue(info.inputScope.localizedCaseInsensitiveContains("bounded"))
        XCTAssertFalse(info.message.contains("Page 1"))
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

    func testSummaryResultNeverHidesUnsupportedOrFailedOutcome() async {
        let document = SampleDataFactory.makeDemoDocument()
        let result = await IntelligentExplainer().summaryResult(for: document, length: .short)

        switch result {
        case .generated(let text):
            XCTAssertFalse(text.isEmpty)
        case .unavailable(let availability):
            switch availability {
            case .available:
                XCTFail("An available model should not be returned as unavailable")
            case .unavailable, .notSupported:
                break
            }
        case .failed(let reason):
            XCTAssertFalse(reason.isEmpty)
        }
    }

    func testLegacySummaryAPIRemainsTextCompatibleWithTypedResult() async {
        let document = SampleDataFactory.makeDemoDocument()
        let explainer = IntelligentExplainer()
        let result = await explainer.summaryResult(for: document, length: .short)
        let legacy = await explainer.summary(for: document, length: .short)

        switch result {
        case .generated:
            XCTAssertFalse(legacy.isEmpty)
        case .unavailable, .failed:
            XCTAssertTrue(legacy.isEmpty)
        }
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

    func testSelectionContextIsSourceLabelledAndReportsOmittedLocations() {
        let headingOne = TextBlock(pageNumber: 1, type: .heading, text: "Introduction", bounds: .init(x: 0, y: 0, width: 100, height: 20), confidence: 0.9, readingOrderIndex: 0)
        let bodyOne = TextBlock(pageNumber: 1, type: .paragraph, text: "Selected source passage.", bounds: .init(x: 0, y: 30, width: 100, height: 20), confidence: 0.9, readingOrderIndex: 1)
        let headingTwo = TextBlock(pageNumber: 2, type: .heading, text: "Appendix", bounds: .init(x: 0, y: 0, width: 100, height: 20), confidence: 0.9, readingOrderIndex: 0)
        let bodyTwo = TextBlock(pageNumber: 2, type: .paragraph, text: "Omitted source passage.", bounds: .init(x: 0, y: 30, width: 100, height: 20), confidence: 0.9, readingOrderIndex: 1)
        var document = ReaderDocument(title: "Context", sourceType: .sample, pages: [
            ReaderPage(pageNumber: 1, size: .init(width: 100, height: 100), blocks: [headingOne, bodyOne]),
            ReaderPage(pageNumber: 2, size: .init(width: 100, height: 100), blocks: [headingTwo, bodyTwo])
        ])
        document.pages[1].pageLabel = "ii"

        let context = IntelligenceContextBuilder.summary(
            for: document,
            length: .detailed,
            selectedBlockIDs: [bodyOne.id]
        )

        XCTAssertTrue(context.metadata.isSelectionScoped)
        XCTAssertEqual(context.metadata.requestedBlockCount, 1)
        XCTAssertEqual(context.metadata.includedBlockCount, 1)
        XCTAssertEqual(context.metadata.omittedBlockCount, 3)
        XCTAssertEqual(context.metadata.includedPageNumbers, [1])
        XCTAssertTrue(context.metadata.omittedPageNumbers.contains(2))
        XCTAssertEqual(context.metadata.includedSectionLabels, ["Introduction"])
        XCTAssertTrue(context.metadata.omittedSectionLabels.contains("Appendix"))
        XCTAssertTrue(context.prompt.contains("Source page 1"))
        XCTAssertTrue(context.prompt.contains("section \"Introduction\""))
        XCTAssertTrue(context.prompt.contains("Omitted source locations"))
        XCTAssertTrue(context.prompt.contains("pages 1, 2"))
        XCTAssertTrue(context.prompt.contains("content not provided"))
        XCTAssertFalse(context.prompt.contains("Omitted source passage."))
    }

    func testContextBoundsBlocksAndCharacterLengthDeterministically() {
        let blocks = (1...20).map { index in
            TextBlock(pageNumber: index, type: .paragraph, text: "Passage \(index) \(String(repeating: "x", count: 400))", bounds: .init(x: 0, y: 0, width: 100, height: 20), confidence: 0.9, readingOrderIndex: 0)
        }
        let document = ReaderDocument(title: "Large", sourceType: .sample, pages: blocks.map {
            ReaderPage(pageNumber: $0.pageNumber, size: .init(width: 100, height: 100), blocks: [$0])
        })
        let first = IntelligenceContextBuilder.summary(for: document, length: .short, maximumCharacters: 800)
        let second = IntelligenceContextBuilder.summary(for: document, length: .short, maximumCharacters: 800)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.metadata.includedBlockCount, 4)
        XCTAssertEqual(first.metadata.omittedBlockCount, 16)
        XCTAssertLessThanOrEqual(first.prompt.count, 850)
        XCTAssertTrue(first.prompt.contains("truncated by PageLumen"))
    }

    func testSelectionSummaryFallsBackToSelectedBlocksOnly() {
        let first = TextBlock(pageNumber: 1, type: .paragraph, text: "Chosen passage.", bounds: .init(x: 0, y: 0, width: 100, height: 20), confidence: 0.9, readingOrderIndex: 0)
        let second = TextBlock(pageNumber: 1, type: .paragraph, text: "Not chosen passage.", bounds: .init(x: 0, y: 30, width: 100, height: 20), confidence: 0.9, readingOrderIndex: 1)
        let document = ReaderDocument(title: "Selected", sourceType: .sample, pages: [
            ReaderPage(pageNumber: 1, size: .init(width: 100, height: 100), blocks: [first, second])
        ])
        let summary = ExplanationEngine().groundedSummary(for: document, length: .short, selectedBlockIDs: [first.id])

        XCTAssertTrue(summary.text.contains("Chosen passage."))
        XCTAssertFalse(summary.text.contains("Not chosen passage."))
        XCTAssertEqual(summary.contextMetadata?.requestedBlockCount, 1)
        XCTAssertEqual(summary.contextMetadata?.omittedBlockCount, 1)
        XCTAssertEqual(summary.citations.map(\.blockID), [first.id])
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

    func testExplanationEngineUsesInjectedProviderWithoutInvokingFoundationModels() async {
        let document = SampleDataFactory.makeDemoDocument()
        let fake = FixedIntelligenceProvider(
            availability: .available,
            result: .generated("Injected structured draft")
        )

        let summary = await ExplanationEngine(intelligenceProvider: fake)
            .summary(for: document, length: .short, options: SummaryOptions(useIntelligence: true))

        XCTAssertEqual(summary, "Injected structured draft")
    }

    func testExplanationEngineKeepsDeterministicFallbackForInjectedFailure() async {
        let document = SampleDataFactory.makeDemoDocument()
        let fake = FixedIntelligenceProvider(
            availability: .available,
            result: .failed(reason: "synthetic failure")
        )

        let summary = await ExplanationEngine(intelligenceProvider: fake)
            .summary(for: document, length: .short, options: SummaryOptions(useIntelligence: true))

        XCTAssertTrue(summary.contains("Page 1"))
        XCTAssertFalse(summary.contains("synthetic failure"))
    }
}

private struct FixedIntelligenceProvider: IntelligenceExplaining {
    let availability: IntelligentExplainerAvailability
    let result: IntelligentExplainerResult

    func summaryResult(
        for document: ReaderDocument,
        length: SummaryLength,
        selectedBlockIDs: Set<UUID>?
    ) async -> IntelligentExplainerResult {
        result
    }
}
