import XCTest
@testable import PageLumenCore

final class PDFUADirectionTests: XCTestCase {
    func testReadablePDFPrototypeReportsObservableEvidenceAndKnownGaps() {
        let pdf = ExportEngine().pdfData(for: SampleDataFactory.makeDemoDocument(), options: .full)
        let result = PDFUADirectionValidator.assess(pdfData: pdf)

        XCTAssertGreaterThan(result.generatedPageCount, 0)
        XCTAssertFalse(result.isPDFUAConformant)
        XCTAssertEqual(result.recommendedAlternative, "Tagged HTML")
        XCTAssertEqual(result.checks.first(where: { $0.id == "pdf.parseable" })?.status, .passed)
        XCTAssertEqual(result.checks.first(where: { $0.id == "pdf.selectable-text" })?.status, .passed)
        XCTAssertEqual(result.checks.first(where: { $0.id == "pdf.structure-tree" })?.status, .notImplemented)
        XCTAssertTrue(result.report.contains("PDF/UA conformance: not asserted"))
    }

    func testMalformedBytesAreUnavailableRatherThanConformant() {
        let result = PDFUADirectionValidator.assess(pdfData: Data("not a pdf".utf8))

        XCTAssertEqual(result.generatedPageCount, 0)
        XCTAssertFalse(result.isPDFUAConformant)
        XCTAssertEqual(result.checks.map(\.status), [.unavailable])
    }
}
