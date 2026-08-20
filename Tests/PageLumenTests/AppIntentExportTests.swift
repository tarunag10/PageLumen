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

    func testEmptyLibraryProducesNoDocumentOrFindingEntities() {
        let repository = IntentRepositoryStub()

        XCTAssertTrue(PageLumenIntentBridge.entities(from: repository).isEmpty)
        XCTAssertTrue(PageLumenIntentBridge.findingEntities(in: repository).isEmpty)
    }

    func testRevokedRepositoryAccessFailsClosedWithoutExportingEntitiesOrSummary() {
        let repository = RevokedRepositoryStub()

        XCTAssertTrue(PageLumenIntentBridge.entities(from: repository).isEmpty)
        XCTAssertTrue(PageLumenIntentBridge.findingEntities(in: repository).isEmpty)
        XCTAssertNil(PageLumenCoreSummaryBridge.currentSummary(from: repository))
    }

    func testDisabledIntelligenceLeavesDeterministicLocalSummaryAvailable() {
        let key = "intelligenceMode"
        let previous = UserDefaults.standard.object(forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        UserDefaults.standard.set(IntelligenceMode.off.rawValue, forKey: key)

        let document = ReaderDocument(title: "Summary", sourceType: .sample, pages: [], summary: "Local summary")
        let metadata = DocumentMetadata(
            id: document.id,
            title: document.title,
            sourceType: document.sourceType,
            sourceURL: nil,
            createdAt: document.createdAt,
            language: nil,
            processingStatus: .complete,
            pageCount: 0,
            unresolvedFindingCount: 0
        )

        XCTAssertEqual(
            PageLumenCoreSummaryBridge.currentSummary(
                from: IntentRepositoryStub(metadata: [metadata], document: document)
            ),
            "Local summary"
        )
    }

    func testFindingEntitiesRemainAvailableWhenIntelligenceIsDisabled() {
        let key = "intelligenceMode"
        let previous = UserDefaults.standard.object(forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        UserDefaults.standard.set(IntelligenceMode.off.rawValue, forKey: key)

        var document = SampleDataFactory.makeDemoDocument()
        document.pages[0].blocks[0].confidence = 0.1
        let entities = PageLumenIntentBridge.findingEntities(in: document)

        XCTAssertFalse(entities.isEmpty)
        XCTAssertTrue(entities.allSatisfy { !$0.isResolved })
        XCTAssertTrue(entities.allSatisfy { $0.documentID == document.id })
    }

    func testFindingEntityNeverExportsRawOCRDetailOrCompatibilityID() {
        let secret = "PRIVATE OCR CONTENT 9B4F"
        var document = SampleDataFactory.makeDemoDocument()
        document.pages[0].blocks[0].text = secret
        document.pages[0].blocks[0].confidence = 0.1

        let entities = PageLumenIntentBridge.findingEntities(in: document)
        XCTAssertFalse(entities.isEmpty)
        for entity in entities {
            XCTAssertFalse(entity.id.contains(secret))
            XCTAssertFalse(entity.documentTitle.contains(secret))
            XCTAssertFalse(entity.displayRepresentationDescription.contains(secret))
        }
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

    func testSummaryBridgeReturnsLatestSummaryAndNilForEmptyLibrary() {
        let empty = IntentRepositoryStub()
        XCTAssertNil(PageLumenCoreSummaryBridge.currentSummary(from: empty))

        let document = ReaderDocument(title: "Summary", sourceType: .sample, pages: [], summary: "Grounded local summary")
        let metadata = DocumentMetadata(
            id: document.id,
            title: document.title,
            sourceType: document.sourceType,
            sourceURL: nil,
            createdAt: document.createdAt,
            language: nil,
            processingStatus: .complete,
            pageCount: 0,
            unresolvedFindingCount: 0
        )
        let populated = IntentRepositoryStub(metadata: [metadata], document: document)
        XCTAssertEqual(PageLumenCoreSummaryBridge.currentSummary(from: populated), "Grounded local summary")
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

    func testApplicationOpenFilesBridgesFinderOpenToDocumentRequest() {
        let center = NotificationCenter.default
        let url = URL(fileURLWithPath: "/tmp/from-finder.pdf")
        var received: URL?
        let token = center.addObserver(forName: .pageLumenOpenDocumentRequest, object: nil, queue: nil) {
            received = $0.userInfo?["url"] as? URL
        }
        defer { center.removeObserver(token) }

        AppDelegate().application(NSApplication.shared, open: [url])

        XCTAssertEqual(received, url)
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

#if canImport(AppIntents)
private extension PageLumenFindingEntity {
    /// XCTest cannot inspect localized display fields directly on every
    /// supported SDK, so this keeps the disclosure assertion SDK-stable.
    var displayRepresentationDescription: String {
        String(describing: displayRepresentation)
    }
}
#endif

private final class IntentRepositoryStub: DocumentRepository, @unchecked Sendable {
    let metadata: [DocumentMetadata]
    let searchResults: [LibrarySearchResult]
    let documentValue: ReaderDocument?
    private(set) var lastSearchLimit: Int?

    init(metadata: [DocumentMetadata] = [], searchResults: [LibrarySearchResult] = [], document: ReaderDocument? = nil) {
        self.metadata = metadata
        self.searchResults = searchResults
        self.documentValue = document
    }

    func recentMetadata() throws -> [DocumentMetadata] { metadata }
    func metadata(id: UUID) throws -> DocumentMetadata? { metadata.first { $0.id == id } }
    func document(id: UUID) throws -> ReaderDocument? { documentValue?.id == id ? documentValue : nil }
    func search(query: String, limit: Int) throws -> [LibrarySearchResult] {
        lastSearchLimit = limit
        return Array(searchResults.prefix(limit))
    }
}

private final class RevokedRepositoryStub: DocumentRepository, @unchecked Sendable {
    private enum AccessError: Error { case permissionRevoked }

    func recentMetadata() throws -> [DocumentMetadata] { throw AccessError.permissionRevoked }
    func metadata(id: UUID) throws -> DocumentMetadata? { throw AccessError.permissionRevoked }
    func document(id: UUID) throws -> ReaderDocument? { throw AccessError.permissionRevoked }
    func search(query: String, limit: Int) throws -> [LibrarySearchResult] { throw AccessError.permissionRevoked }
}
#endif
