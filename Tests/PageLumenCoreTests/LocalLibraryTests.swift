import Foundation
import XCTest
@testable import PageLumenCore

final class LocalLibraryTests: XCTestCase {
    func testSearchReturnsPrivacySafeDocumentAndPageSnippets() throws {
        let persisting = FilePersisting(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("pagelumen-library-\(UUID().uuidString).json"))
        let document = SampleDataFactory.makeDemoDocument()
        try persisting.save(document)

        let results = try LocalDocumentRepository(persisting: persisting, keepSearchableLocalCopies: true).search(query: "import flow", limit: 10)

        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results.first?.documentID, document.id)
        XCTAssertEqual(results.first?.title, document.title)
        XCTAssertGreaterThanOrEqual(results.first?.pageNumber ?? 0, 1)
        XCTAssertFalse(results.first?.snippet.isEmpty ?? true)
    }

    func testSearchRequiresAllTermsAndHonoursLimit() throws {
        let persisting = FilePersisting(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("pagelumen-library-\(UUID().uuidString).json"))
        try persisting.save(SampleDataFactory.makeDemoDocument())
        let repository = LocalDocumentRepository(persisting: persisting, keepSearchableLocalCopies: true)

        XCTAssertTrue(try repository.search(query: "term-that-does-not-exist", limit: 10).isEmpty)
        XCTAssertLessThanOrEqual(try repository.search(query: "document", limit: 1).count, 1)
    }

    func testUnresolvedFindingCountMatchesReviewEngine() throws {
        let document = SampleDataFactory.makeDemoDocument()
        let persisting = FilePersisting(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("pagelumen-library-\(UUID().uuidString).json"))
        try persisting.save(document)

        let repository = LocalDocumentRepository(persisting: persisting)
        let metadata = try XCTUnwrap(repository.metadata(id: document.id))
        XCTAssertEqual(metadata.unresolvedFindingCount, DocumentEditing.reviewFindings(for: document).count)
    }

    func testRecentMetadataDoesNotRequireLoadingFullDocumentPayload() throws {
        let document = SampleDataFactory.makeDemoDocument()
        let persisting = FilePersisting(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("pagelumen-library-\(UUID().uuidString).json"))
        try persisting.save(document)

        let repository: any DocumentRepository = LocalDocumentRepository(persisting: persisting)
        let metadata = try XCTUnwrap(repository.recentMetadata().first)

        XCTAssertEqual(metadata.id, document.id)
        XCTAssertEqual(metadata.title, document.title)
        XCTAssertEqual(metadata.pageCount, document.pageCount)
        XCTAssertEqual(metadata.sourceType, document.sourceType)
        XCTAssertEqual(metadata.unresolvedFindingCount, DocumentEditing.reviewFindings(for: document).count)
        XCTAssertNil(try repository.metadata(id: UUID()))
        XCTAssertEqual(try repository.document(id: document.id)?.pages.count, document.pages.count)
    }

    func testSearchIsOptInWhileRecentsMetadataRemainsAvailable() throws {
        let document = SampleDataFactory.makeDemoDocument()
        let persisting = FilePersisting(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("pagelumen-library-\(UUID().uuidString).json"))
        try persisting.save(document)

        let repository = LocalDocumentRepository(persisting: persisting)

        XCTAssertTrue(try repository.search(query: "import flow", limit: 10).isEmpty)
        XCTAssertEqual(try repository.recentMetadata().first?.id, document.id)
        XCTAssertEqual(try repository.metadata(id: document.id)?.pageCount, document.pageCount)
    }
}
