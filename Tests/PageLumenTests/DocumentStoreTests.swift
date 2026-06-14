import AppKit
import Combine
import Foundation
import PageLumenCore
import XCTest
@testable import PageLumen

@MainActor
final class DocumentStoreTests: XCTestCase {
    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "languageHint")
        UserDefaults.standard.removeObject(forKey: "includeHeadings")
        UserDefaults.standard.removeObject(forKey: "includeTables")
        UserDefaults.standard.removeObject(forKey: "includeFigures")
        UserDefaults.standard.removeObject(forKey: "includePageReferences")
        UserDefaults.standard.removeObject(forKey: "includeConfidenceNotes")
        UserDefaults.standard.removeObject(forKey: "includeHeadersAndFooters")
        try await super.tearDown()
    }

    func testLoadSampleResetsDocumentAndNavigatesToReview() {
        let store = DocumentStore(persisting: InMemoryPersisting())

        store.loadSample()

        XCTAssertEqual(store.document.title, "PageLumen Demo")
        XCTAssertEqual(store.selectedDestination, .review)
    }

    func testMoveBlockUpdatesReadingOrder() {
        let store = DocumentStore(persisting: InMemoryPersisting())
        let document = makeMoveDocument()
        store.document = document

        let firstBlock = document.pages[0].blocks[0]
        let thirdBlock = document.pages[0].blocks[2]

        store.moveBlock(thirdBlock, direction: .up)
        store.moveBlock(thirdBlock, direction: .up)

        XCTAssertEqual(
            store.document.pages[0].blocks.map(\.readingOrderIndex),
            [0, 1, 2]
        )
        XCTAssertEqual(
            store.document.pages[0].blocks.map(\.text),
            ["Third", "First", "Second"]
        )

        // Suppress unused warning while keeping the helper reachable.
        _ = firstBlock
    }

    func testMarkBlockReviewedUpdatesReviewProgress() {
        let store = DocumentStore(persisting: InMemoryPersisting())
        let block = store.document.pages[0].blocks[0]
        let before = store.reviewProgress.reviewedBlocks

        store.setBlockReviewed(block, isReviewed: true)

        XCTAssertEqual(store.reviewProgress.reviewedBlocks, before + 1)
        XCTAssertTrue(DocumentEditing.isReviewed(store.document.pages[0].blocks[0]))
    }

    func testExportPreviewTextCachesForSameInputs() {
        let store = DocumentStore(persisting: InMemoryPersisting())

        let first = store.exportPreviewText()
        let second = store.exportPreviewText()
        XCTAssertEqual(first, second, "Two back-to-back calls should return the same preview text")

        // A "light" mutation that doesn't change the document version should
        // still hit the cache, so the rendered text reflects the previous
        // document state, not the mutated one.
        if let block = store.document.allBlocks.first {
            store.updateBlock(block, text: "MUTATED CONTENT FOR CACHE TEST")
        }
        let afterMutation = store.exportPreviewText()
        XCTAssertEqual(afterMutation, first, "Cache should be hit despite a non-versioned mutation")
        XCTAssertFalse(afterMutation.contains("MUTATED CONTENT FOR CACHE TEST"))
    }

    func testExportPreviewTextReRendersWhenDocumentChanges() {
        let store = DocumentStore(persisting: InMemoryPersisting())

        let first = store.exportPreviewText()
        XCTAssertTrue(first.contains("PageLumen Demo"))

        // Swapping the document changes the version, which invalidates the
        // cache. The new document uses a different title so the rendered text
        // must change.
        var replacement = SampleDataFactory.makeDemoDocument()
        replacement.title = "Cache Replacement Title"
        store.document = replacement

        let second = store.exportPreviewText()
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(second.contains("Cache Replacement Title"))
    }

    func testForgetAllRecentDocumentsEmptiesLibrary() {
        let persisting = InMemoryPersisting()
        let store = DocumentStore(persisting: persisting)

        XCTAssertFalse(store.recentDocuments.isEmpty)
        let initial = store.recentDocuments.count

        store.forgetAllRecentDocuments()

        XCTAssertTrue(store.recentDocuments.isEmpty)
        XCTAssertTrue(try persisting.recentDocuments().isEmpty)
        XCTAssertNotEqual(store.recentDocuments.count, initial)
    }

    func testDebouncedUpdateBlockOnlyLandsLastValue() {
        let store = DocumentStore(persisting: InMemoryPersisting())
        let block = store.document.pages[0].blocks[0]

        // The debounce lives in `EditableBlockRow` (ReviewView.swift), not in
        // the store, so this test verifies the store's end-to-end behavior:
        // rapid `updateBlock` calls all resolve, and the final value is the
        // one that sticks. The view layer's debounce is what prevents the
        // store from ever being called with intermediate values during fast
        // typing.
        let values = ["first", "second", "third", "fourth", "final"]
        for value in values {
            store.updateBlock(block, text: value)
        }

        let landed = store.document.pages[0].blocks.first(where: { $0.id == block.id })?.text
        XCTAssertEqual(landed, "final")
    }

    func testReorderBlockMovesBlockToDestinationIndex() {
        let store = DocumentStore(persisting: InMemoryPersisting())
        store.document = makeMoveDocument()

        let thirdBlock = store.document.pages[0].blocks[2]

        // Move "Third" (index 2) all the way to index 0.
        store.reorderBlock(id: thirdBlock.id, to: 0)

        XCTAssertEqual(
            store.document.pages[0].blocks.map(\.text),
            ["Third", "First", "Second"]
        )
        XCTAssertEqual(
            store.document.pages[0].blocks.map(\.readingOrderIndex),
            [0, 1, 2],
            "Reading-order index should be recomputed after a reorder"
        )

        // Moving the same block back to its original tail position should be
        // a no-op-friendly round-trip.
        let nowFirst = store.document.pages[0].blocks[0]
        store.reorderBlock(id: nowFirst.id, to: 2)
        XCTAssertEqual(
            store.document.pages[0].blocks.map(\.text),
            ["First", "Second", "Third"]
        )
    }

    func testSearchIndexFindsMatches() {
        let store = DocumentStore(persisting: InMemoryPersisting())
        store.document = makeSearchableDocument()

        let expectedImportMatches = store.document.allBlocks.filter { $0.text.localizedCaseInsensitiveContains("import") }.count
        XCTAssertGreaterThan(expectedImportMatches, 0)
        store.reviewSearchQuery = "import"
        XCTAssertEqual(store.reviewSearchMatchCount, expectedImportMatches)

        let page = store.selectedPage ?? store.document.pages[0]
        let expected = page.blocks.filter { $0.text.localizedCaseInsensitiveContains("import") }
        XCTAssertEqual(store.filteredSelectedPageBlocks.map(\.id).sorted(), expected.map(\.id).sorted())
    }

    func testSearchIndexInvalidatesOnDocumentChange() {
        let store = DocumentStore(persisting: InMemoryPersisting())
        store.document = makeSearchableDocument()

        store.reviewSearchQuery = "import"
        let initial = store.reviewSearchMatchCount
        XCTAssertGreaterThan(initial, 0)

        store.document = makeDifferentSearchableDocument()
        store.reviewSearchQuery = "auditable"
        let updated = store.reviewSearchMatchCount
        XCTAssertEqual(updated, 1, "Index should rebuild and find the single new match")

        store.reviewSearchQuery = "import"
        XCTAssertEqual(store.reviewSearchMatchCount, 0)
    }

    private func makeSearchableDocument() -> ReaderDocument {
        let page = ReaderPage(
            pageNumber: 1,
            size: PageSize(width: 400, height: 600),
            blocks: [
                TextBlock(pageNumber: 1, type: .paragraph, text: "The first paragraph explains the import flow.", bounds: BoundingBox(x: 0, y: 0, width: 100, height: 20), confidence: 0.9, readingOrderIndex: 0),
                TextBlock(pageNumber: 1, type: .paragraph, text: "The second paragraph talks about export.", bounds: BoundingBox(x: 0, y: 40, width: 100, height: 20), confidence: 0.9, readingOrderIndex: 1),
                TextBlock(pageNumber: 1, type: .paragraph, text: "The third paragraph is just narration.", bounds: BoundingBox(x: 0, y: 80, width: 100, height: 20), confidence: 0.9, readingOrderIndex: 2)
            ]
        )
        return ReaderDocument(title: "Search Doc", sourceType: .sample, pages: [page])
    }

    private func makeDifferentSearchableDocument() -> ReaderDocument {
        let page = ReaderPage(
            pageNumber: 1,
            size: PageSize(width: 400, height: 600),
            blocks: [
                TextBlock(pageNumber: 1, type: .paragraph, text: "This is now an auditable flow.", bounds: BoundingBox(x: 0, y: 0, width: 100, height: 20), confidence: 0.9, readingOrderIndex: 0)
            ]
        )
        return ReaderDocument(title: "Search Doc v2", sourceType: .sample, pages: [page])
    }

    private func makeMoveDocument() -> ReaderDocument {
        let first = TextBlock(pageNumber: 1, type: .paragraph, text: "First", bounds: BoundingBox(x: 20, y: 20, width: 100, height: 20), confidence: 0.9, readingOrderIndex: 0)
        let second = TextBlock(pageNumber: 1, type: .paragraph, text: "Second", bounds: BoundingBox(x: 20, y: 60, width: 100, height: 20), confidence: 0.9, readingOrderIndex: 1)
        let third = TextBlock(pageNumber: 1, type: .paragraph, text: "Third", bounds: BoundingBox(x: 20, y: 100, width: 100, height: 20), confidence: 0.9, readingOrderIndex: 2)
        return ReaderDocument(
            title: "Move",
            sourceType: .sample,
            pages: [ReaderPage(pageNumber: 1, size: PageSize(width: 400, height: 600), blocks: [first, second, third])]
        )
    }
}

private final class InMemoryPersisting: DocumentPersisting, @unchecked Sendable {
    private var storage: [UUID: ReaderDocument] = [:]
    private var order: [UUID] = []

    func save(_ document: ReaderDocument) throws {
        if storage[document.id] == nil {
            order.append(document.id)
        }
        storage[document.id] = document
    }

    func load(id: UUID) throws -> ReaderDocument? {
        storage[id]
    }

    func recentDocuments() throws -> [ReaderDocument] {
        order.compactMap { storage[$0] }
    }

    func forgetAll() throws {
        storage.removeAll()
        order.removeAll()
    }
}
