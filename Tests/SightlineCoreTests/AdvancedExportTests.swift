import XCTest
@testable import SightlineCore

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

        XCTAssertEqual(object?["title"] as? String, "Sightline Reader Demo")
        XCTAssertNotNil(object?["pages"] as? [[String: Any]])
        XCTAssertNotNil(object?["summary"] as? String)
    }
}
