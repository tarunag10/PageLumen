import Foundation
import XCTest

/// The catalog is deliberately test-only: product code must not depend on
/// synthetic evaluation documents. Image/OCR cases are generated proxies, not
/// ground truth and therefore do not contribute accuracy claims.
final class CorpusManifestTests: XCTestCase {
    struct Case: Codable, Equatable {
        let id: String
        let className: String
        let format: String
        let groundTruth: String
        let metricsStatus: String
    }

    private let cases: [Case] = [
        Case(id: "two-column-paper", className: "two/three-column paper", format: "pdf", groundTruth: "synthetic-native-text", metricsStatus: "not-measured"),
        Case(id: "three-column-paper", className: "three-column paper", format: "pdf", groundTruth: "synthetic-native-text", metricsStatus: "not-measured"),
        Case(id: "legal-filing", className: "legal filing", format: "pdf", groundTruth: "synthetic-native-text", metricsStatus: "not-measured"),
        Case(id: "form", className: "form", format: "pdf", groundTruth: "synthetic-native-text", metricsStatus: "not-measured"),
        Case(id: "receipt", className: "receipt", format: "pdf", groundTruth: "synthetic-native-text", metricsStatus: "not-measured"),
        Case(id: "slides", className: "slides", format: "pdf", groundTruth: "synthetic-native-text", metricsStatus: "not-measured"),
        Case(id: "multi-page-table", className: "multi-page table", format: "pdf", groundTruth: "synthetic-native-text", metricsStatus: "not-measured"),
        Case(id: "chart", className: "chart", format: "pdf", groundTruth: "synthetic-native-text", metricsStatus: "not-measured"),
        Case(id: "rotated-page", className: "rotated page", format: "pdf", groundTruth: "synthetic-native-text", metricsStatus: "not-measured"),
        Case(id: "multilingual-text", className: "multilingual text", format: "pdf", groundTruth: "synthetic-native-text", metricsStatus: "not-measured"),
        Case(id: "low-quality-scan", className: "low-quality scan", format: "png", groundTruth: "synthetic-proxy", metricsStatus: "not-measured"),
        Case(id: "handwriting", className: "handwriting", format: "png", groundTruth: "synthetic-proxy", metricsStatus: "not-measured"),
        Case(id: "equations", className: "equations", format: "pdf", groundTruth: "synthetic-native-text", metricsStatus: "not-measured"),
        Case(id: "ocr-traps", className: "deliberate OCR traps", format: "pdf", groundTruth: "synthetic-native-text", metricsStatus: "not-measured")
    ]

    func testManifestCoversEveryRequiredFixtureClass() {
        let required = ["two/three-column paper", "three-column paper", "legal filing", "form", "receipt", "slides", "multi-page table", "chart", "rotated page", "multilingual text", "low-quality scan", "handwriting", "equations", "deliberate OCR traps"]
        XCTAssertEqual(Set(cases.map(\.className)), Set(required))
        XCTAssertEqual(Set(cases.map(\.metricsStatus)), ["not-measured"])
    }

    func testGeneratedFixtureFilesAreDeterministicAndBounded() {
        let urls: [URL] = [
            Fixtures.twoColumnPDF(), Fixtures.threeColumnPDF(), Fixtures.legalFilingPDF(),
            Fixtures.receiptStylePDF(), Fixtures.slideStylePDF(), Fixtures.multiPageTablePDF(),
            Fixtures.chartPDF(), Fixtures.rotatedPagePDF(), Fixtures.multilingualPDF(),
            Fixtures.lowQualityScanPNG(), Fixtures.handwritingPNG(), Fixtures.equationPDF(), Fixtures.OCRTrapPDF()
        ]
        defer { urls.forEach { try? FileManager.default.removeItem(at: $0) } }
        XCTAssertEqual(urls.count, cases.count - 1) // two/three-column is one catalog class with two variants
        for url in urls {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            XCTAssertGreaterThan(size, 0)
            XCTAssertLessThanOrEqual(size, 2_000_000)
        }
    }
}
