import XCTest
@testable import PageLumenCore

final class FixtureCorpusTests: XCTestCase {
    func testTwoColumnPDFReadingOrderPreservesParagraphOrder() async throws {
        let url = Fixtures.twoColumnPDF()
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try await DocumentProcessor().process(url: url)
        let analyzed = LayoutAnalyzer().analyze(document: document)
        let texts = analyzed.allBlocks.map(\.text)

        XCTAssertEqual(
            texts,
            ["Left top", "Left bottom", "Right top", "Right bottom"]
        )
    }

    func testSlideStylePDFIsClassifiedAsSlide() async throws {
        let url = Fixtures.slideStylePDF()
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try await DocumentProcessor().process(url: url)
        let analyzed = LayoutAnalyzer(profile: .slides).analyze(document: document)

        XCTAssertEqual(analyzed.pages.first?.layoutType, .slide)
        XCTAssertGreaterThanOrEqual(analyzed.pages.first?.blocks.count ?? 0, 1)
    }

    func testReceiptStylePDFPromotesKeyValueRowsToTable() async throws {
        let url = Fixtures.receiptStylePDF()
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try await DocumentProcessor().process(url: url)
        let analyzed = LayoutAnalyzer(profile: .receipts).analyze(document: document)

        XCTAssertEqual(analyzed.pages.first?.layoutType, .form)
        let rows = analyzed.pages.first?.tables.first?.rows ?? []
        XCTAssertGreaterThanOrEqual(rows.count, 2)
        XCTAssertEqual(rows.first, ["Subtotal", "$18.50"])
        XCTAssertEqual(rows.last, ["Total", "$19.98"])
    }

    func testTinyPDFContainsEmbeddedText() async throws {
        let url = Fixtures.tinyPDF(text: "Tiny fixture text for PageLumen")
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try await DocumentProcessor().process(url: url)

        XCTAssertEqual(document.pageCount, 1)
        XCTAssertTrue(
            document.allBlocks.contains { $0.text.contains("Tiny fixture text for PageLumen") }
        )
    }

    func testScreenshotPNGProcessesIntoReaderDocument() async throws {
        let url = Fixtures.screenshotPNG(text: "Screenshot OCR Sample")
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try await DocumentProcessor().process(url: url)

        XCTAssertEqual(document.sourceType, .image)
        XCTAssertEqual(document.pageCount, 1)
        XCTAssertEqual(document.processingStatus, .complete)
    }
}
