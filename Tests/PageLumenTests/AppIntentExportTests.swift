#if canImport(AppIntents)
import AppIntents
import Foundation
import PageLumenCore
import XCTest
@testable import PageLumen

final class AppIntentExportTests: XCTestCase {
    func testEntityQueryMapsOnlyMetadataAndPreservesPrivacySafeCounts() {
        let id = UUID()
        let repository = IntentRepositoryStub(metadata: [
            DocumentMetadata(
                id: id,
                title: "Retained report",
                sourceType: .sample,
                sourceURL: nil,
                createdAt: Date(timeIntervalSince1970: 1),
                language: "en",
                processingStatus: .complete,
                pageCount: 4,
                unresolvedFindingCount: 2
            )
        ])

        let entities = PageLumenIntentBridge.entities(from: repository)
        XCTAssertEqual(entities.count, 1)
        XCTAssertEqual(entities[0].id, id)
        XCTAssertEqual(entities[0].title, "Retained report")
        XCTAssertEqual(entities[0].pageCount, 4)
        XCTAssertEqual(entities[0].unresolvedFindings, 2)
    }

    func testSearchBridgeIsBoundedAndUsesRepositoryRetentionGate() throws {
        let allowed = IntentRepositoryStub(searchResults: [
            LibrarySearchResult(documentID: UUID(), title: "Report", pageNumber: 3, blockID: nil, snippet: "matching text")
        ])
        XCTAssertEqual(try PageLumenIntentBridge.search(query: "matching", in: allowed).count, 1)
        XCTAssertEqual(allowed.lastSearchLimit, 10)

        let disabled = IntentRepositoryStub(searchResults: [])
        XCTAssertTrue(try PageLumenIntentBridge.search(query: "matching", in: disabled).isEmpty)
        XCTAssertEqual(disabled.lastSearchLimit, 10)
    }

    func testFindingsBridgeReturnsOnlyUnresolvedFindings() {
        var document = SampleDataFactory.makeDemoDocument()
        DocumentEditing.setBlockReviewed(id: document.pages[0].blocks[0].id, isReviewed: true, in: &document)

        let findings = PageLumenIntentBridge.unresolvedFindings(in: document)
        XCTAssertTrue(findings.allSatisfy { !$0.isResolved })
    }

    func testOpenIntentNotificationHelpersCarryOnlySelectedResource() {
        let center = NotificationCenter()
        let url = URL(fileURLWithPath: "/tmp/report.pdf")
        let documentID = UUID()
        var receivedURL: URL?
        var receivedID: UUID?
        let urlToken = center.addObserver(forName: .pageLumenOpenDocumentRequest, object: nil, queue: nil) {
            receivedURL = $0.userInfo?["url"] as? URL
        }
        let idToken = center.addObserver(forName: .pageLumenOpenLibraryDocumentRequest, object: nil, queue: nil) {
            receivedID = $0.userInfo?["id"] as? UUID
        }
        defer {
            center.removeObserver(urlToken)
            center.removeObserver(idToken)
        }

        PageLumenIntentBridge.postOpenDocumentRequest(url: url, notificationCenter: center)
        PageLumenIntentBridge.postOpenLibraryDocumentRequest(id: documentID, notificationCenter: center)

        XCTAssertEqual(receivedURL, url)
        XCTAssertEqual(receivedID, documentID)
    }

    func testTaggedHTMLBridgeWritesToCallerProvidedURLWithoutPrompting() throws {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("PageLumen-intent-\(UUID().uuidString)")
            .appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: destination) }

        try PageLumenIntentBridge.exportTaggedHTML(
            document: SampleDataFactory.makeDemoDocument(),
            to: destination
        )

        let html = try String(contentsOf: destination, encoding: .utf8)
        XCTAssertTrue(html.contains("<!doctype html>"))
        XCTAssertTrue(html.contains("PageLumen Demo"))
    }

    func testTaggedHTMLBridgeSurfacesValidationFailure() {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("PageLumen-intent-invalid-\(UUID().uuidString)")
            .appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: destination) }

        let document = ReaderDocument(title: "Empty", sourceType: .sample, pages: [])
        XCTAssertThrowsError(try PageLumenIntentBridge.exportTaggedHTML(document: document, to: destination)) { error in
            guard case PageLumenIntentExportError.validation = error else {
                return XCTFail("Expected a typed Tagged HTML validation error, got \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }
}

private final class IntentRepositoryStub: DocumentRepository, @unchecked Sendable {
    let metadata: [DocumentMetadata]
    let searchResults: [LibrarySearchResult]
    private(set) var lastSearchLimit: Int?

    init(metadata: [DocumentMetadata] = [], searchResults: [LibrarySearchResult] = []) {
        self.metadata = metadata
        self.searchResults = searchResults
    }

    func recentMetadata() throws -> [DocumentMetadata] { metadata }
    func metadata(id: UUID) throws -> DocumentMetadata? { metadata.first { $0.id == id } }
    func document(id: UUID) throws -> ReaderDocument? { nil }
    func search(query: String, limit: Int) throws -> [LibrarySearchResult] {
        lastSearchLimit = limit
        return Array(searchResults.prefix(limit))
    }
}
#endif
