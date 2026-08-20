import XCTest
@testable import PageLumenCore

final class ProcessingBudgetTests: XCTestCase {
    func testEstimateReportsPixelsAndConservativePeakMemory() {
        let estimate = ProcessingBudgetEstimator.estimate(
            pageSizes: [(612, 792), (612, 792)],
            options: .full
        )

        XCTAssertEqual(estimate.pageCount, 2)
        XCTAssertEqual(estimate.selectedPageCount, 2)
        XCTAssertEqual(estimate.peakPagePixels, 1_938_816)
        XCTAssertEqual(estimate.totalPixels, 3_877_632)
        XCTAssertEqual(estimate.estimatedPeakMemoryBytes, 23_265_792)
        XCTAssertFalse(estimate.requiresChoice)
    }

    func testBalancedQualityReducesEstimateWithoutChangingPageSelection() {
        let full = ProcessingBudgetEstimator.estimate(pageSizes: [(2_000, 2_000)], options: .full)
        let balanced = ProcessingBudgetEstimator.estimate(
            pageSizes: [(2_000, 2_000)],
            options: ProcessingImportOptions(quality: .balanced)
        )

        XCTAssertEqual(balanced.selectedPageCount, full.selectedPageCount)
        XCTAssertLessThan(balanced.totalPixels, full.totalPixels)
        XCTAssertLessThan(balanced.estimatedPeakMemoryBytes, full.estimatedPeakMemoryBytes)
    }

    func testPageRangeChoiceBoundsSelectionAndClearsLargeDocumentPrompt() {
        let estimate = ProcessingBudgetEstimator.estimate(
            pageSizes: Array(repeating: (612, 792), count: 101),
            options: .full
        )
        XCTAssertTrue(estimate.requiresChoice)

        let firstHundred = ProcessingBudgetEstimator.estimate(
            pageSizes: Array(repeating: (612, 792), count: 101),
            options: ProcessingImportOptions(pageRange: 1...100)
        )
        XCTAssertEqual(firstHundred.selectedPageCount, 100)
        XCTAssertFalse(firstHundred.requiresChoice)
    }

    func testPerPagePixelBudgetIsReported() {
        let estimate = ProcessingBudgetEstimator.estimate(pageSizes: [(4_000, 4_000)])
        XCTAssertTrue(estimate.exceedsPixelBudget)
        XCTAssertTrue(estimate.requiresChoice)
        XCTAssertGreaterThan(estimate.peakPagePixels, ProcessingBudgetEstimator.maxPagePixels)
    }
}
