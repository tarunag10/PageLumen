import XCTest
@testable import PageLumenCore

final class DocumentComparisonTests: XCTestCase {
    func testChangesInDocumentUsesOriginalOCRAndStableCitation() throws {
        let id = UUID()
        let block = TextBlock(
            id: id,
            pageNumber: 2,
            type: .paragraph,
            text: "Corrected text",
            bounds: BoundingBox(x: 10, y: 20, width: 100, height: 20),
            confidence: 0.8,
            readingOrderIndex: 3,
            originalText: "Original text"
        )
        let document = ReaderDocument(title: "Comparison", sourceType: .sample, pages: [ReaderPage(pageNumber: 2, size: PageSize(width: 400, height: 600), blocks: [block])])

        let change = try XCTUnwrap(DocumentComparison.changes(in: document).first)
        XCTAssertEqual(change.kind, .modified)
        XCTAssertEqual(change.blockID, id)
        XCTAssertEqual(change.pageNumber, 2)
        XCTAssertEqual(change.originalText, "Original text")
        XCTAssertEqual(change.currentText, "Corrected text")
        XCTAssertTrue(change.citation.contains("Page 2"))
        XCTAssertFalse(change.citation.contains("Original text"))
    }

    func testRevisionComparisonReportsAddedRemovedAndModifiedBlocksByID() throws {
        let modifiedID = UUID()
        let removedID = UUID()
        let addedID = UUID()
        func block(_ id: UUID, _ page: Int, _ text: String) -> TextBlock {
            TextBlock(id: id, pageNumber: page, type: .paragraph, text: text, bounds: BoundingBox(x: 0, y: 0, width: 100, height: 20), confidence: 0.9)
        }
        let baseline = ReaderDocument(title: "Before", sourceType: .sample, pages: [ReaderPage(pageNumber: 1, size: PageSize(width: 400, height: 600), blocks: [block(modifiedID, 1, "before"), block(removedID, 1, "removed")])])
        let current = ReaderDocument(title: "After", sourceType: .sample, pages: [ReaderPage(pageNumber: 1, size: PageSize(width: 400, height: 600), blocks: [block(modifiedID, 1, "after"), block(addedID, 1, "added")])])

        let changes = DocumentComparison.changes(from: baseline, to: current)
        XCTAssertEqual(Set(changes.map(\.blockID)), [modifiedID, removedID, addedID])
        XCTAssertEqual(changes.first(where: { $0.blockID == modifiedID })?.kind, .modified)
        XCTAssertEqual(changes.first(where: { $0.blockID == removedID })?.kind, .removed)
        XCTAssertEqual(changes.first(where: { $0.blockID == addedID })?.kind, .added)
    }
}
